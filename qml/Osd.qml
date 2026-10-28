/*
    Glass capsule OSD. Overrides the built-in org.kde.plasma.workspace.osd
    module via QML_IMPORT_PATH, set for plasmashell by install.sh in
    ~/.config/systemd/user/plasma-plasmashell.service.d/plasma-glass-osd.conf.

    A layer-shell surface instead of PlasmaCore.Dialog: Dialog keeps resetting
    the blur region when it has no theme background. The window has a fixed
    size; the capsule animates inside it and the blur region follows the
    capsule shape every frame, since the compositor does not fade blur.
*/

import QtQuick
import QtQuick.Window
import org.kde.layershell as LayerShell
import OsdBlur

Window {
    id: root

    // Interface used by plasmashell
    property alias timeout: osd.timeout
    property alias osdValue: osd.osdValue
    property alias osdMaxValue: osd.osdMaxValue
    property alias osdAdditionalText: osd.osdAdditionalText
    property alias icon: osd.icon
    property alias showingProgress: osd.showingProgress

    // Distance from the top of the screen (below panels), px
    readonly property int topMargin: 40
    readonly property int maxCapsuleWidth: 560
    readonly property int showDuration: 220
    readonly property int hideDuration: 180

    // 0 = collapsed and transparent, 1 = fully shown
    property real reveal: 0

    // Room for the limit stretch around the widest capsule
    width: maxCapsuleWidth + 60
    // Keep the capsule off the window edges: blur rows touching the
    // surface border show up as dark lines
    height: osd.implicitHeight + 4
    color: "transparent"
    flags: Qt.FramelessWindowHint | Qt.WindowDoesNotAcceptFocus | Qt.WindowTransparentForInput

    LayerShell.Window.scope: "osd"
    LayerShell.Window.layer: LayerShell.Window.LayerOverlay
    LayerShell.Window.anchors: LayerShell.Window.AnchorTop
    LayerShell.Window.margins.top: topMargin - 2
    LayerShell.Window.exclusionZone: 0
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone
    LayerShell.Window.activateOnShow: false
    LayerShell.Window.wantsToBeOnActiveScreen: true

    // plasmashell protocol: on every OSD event it sets animateOpacity=false,
    // opacity=1, visible=true, animateOpacity=true, opacity=0 and hides the
    // window after `timeout`. The window itself stays opaque (the animation
    // below barely moves within that time); the capsule does the fading.
    property bool animateOpacity: false
    Behavior on opacity {
        enabled: root.animateOpacity
        ParallelAnimation {
            ScriptAction { script: root.osdTriggered() }
            NumberAnimation { duration: 600000; easing.type: Easing.InExpo }
        }
    }

    // Previous event, to notice key presses against the limit
    property string lastEventKey: ""

    function osdTriggered() {
        const value = Number(osd.osdValue);
        const key = [osd.showingProgress, osd.icon, osd.osdValue, osd.osdAdditionalText].join("|");
        // Plasma resends the same event when a key is pressed at the maximum
        // (a full bar) or at zero (shown as "Audio Muted" text): stretch
        // towards the press like an iOS slider pulled past its end
        const atMax = osd.showingProgress && value >= osd.osdMaxValue;
        const atZero = osd.showingProgress ? value <= 0 : osd.icon.indexOf("muted") !== -1;
        if (key === lastEventKey && (atMax || atZero)) {
            root.pullTowards(atMax ? 1 : -1);
        }
        lastEventKey = key;

        hideAnimation.stop();
        if (reveal < 1 && !showAnimation.running) {
            showAnimation.from = reveal;
            showAnimation.restart();
        }
        hideTimer.interval = Math.max(100, timeout - hideDuration - 40);
        hideTimer.restart();
    }

    onVisibleChanged: {
        showAnimation.stop();
        hideAnimation.stop();
        hideTimer.stop();
        reveal = 0;
        pull = 0;
        stretch = 0;
        stretchVelocity = 0;
        sentBlurRect = Qt.rect(0, 0, 0, 0);
    }

    NumberAnimation {
        id: showAnimation
        target: root
        property: "reveal"
        to: 1
        duration: root.showDuration
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: hideAnimation
        target: root
        property: "reveal"
        to: 0
        duration: root.hideDuration
        easing.type: Easing.InCubic
    }

    // Limit feedback, after UIScrollView as ported by fluid-scroll
    // (github.com/ktiays/fluid-scroll): every key press at the limit adds
    // some virtual "pull" past the end, shown through the rubber-band curve
    // (1 - 1 / (x * 0.55 / d + 1)) * d, which never reaches d. The stretch
    // follows its target with a critically damped spring (no overshoot),
    // and springs back the same way once the key stops repeating.
    readonly property real stretchLimit: 10     // d, px
    readonly property real pullPerPress: 8      // px of virtual pull
    readonly property real pullResponse: 0.147  // s, spring period while pulling
    // s, spring-back; UIKit uses 0.575, this is 1.5x faster
    readonly property real releaseResponse: 0.383
    property real pull: 0
    property real stretch: 0                    // px, shown
    property real stretchVelocity: 0            // px/s
    property real stretchResponse: releaseResponse
    property int stretchDirection: 1
    readonly property real stretchTarget: (1 - 1 / (pull * 0.55 / stretchLimit + 1)) * stretchLimit

    function pullTowards(direction) {
        if (direction !== stretchDirection) {
            pull = 0;
            stretch = 0;
            stretchVelocity = 0;
        }
        stretchDirection = direction;
        pull += pullPerPress;
        stretchResponse = pullResponse;
        stretchHold.restart();
    }

    // Key repeat keeps pulling; let go after a short quiet spell
    Timer {
        id: stretchHold
        interval: 160
        onTriggered: {
            root.pull = 0;
            root.stretchResponse = root.releaseResponse;
        }
    }

    // Exact critically damped step: e(t) = (e0 + (v0 + λ·e0)·t)·e^(-λt)
    FrameAnimation {
        running: root.visible && (root.stretch !== root.stretchTarget || root.stretchVelocity !== 0)
        onTriggered: {
            const dt = Math.min(frameTime, 0.05);
            const lambda = 2 * Math.PI / root.stretchResponse;
            const e0 = root.stretch - root.stretchTarget;
            const c2 = root.stretchVelocity + lambda * e0;
            const decay = Math.exp(-lambda * dt);
            const e = (e0 + c2 * dt) * decay;
            const v = (c2 - lambda * (e0 + c2 * dt)) * decay;
            if (Math.abs(e) < 0.05 && Math.abs(v) < 1) {
                root.stretch = root.stretchTarget;
                root.stretchVelocity = 0;
            } else {
                root.stretch = root.stretchTarget + e;
                root.stretchVelocity = v;
            }
        }
    }

    Timer {
        id: hideTimer
        onTriggered: {
            hideAnimation.from = root.reveal;
            hideAnimation.start();
        }
    }

    // Blur exactly the visible capsule. The region applies on the next
    // surface commit, so request a frame whenever it changes.
    property rect sentBlurRect: Qt.rect(0, 0, 0, 0)

    function syncBlur() {
        if (!visible) {
            return;
        }
        // Round the edges, not x and width separately, so the region never
        // overshoots the antialiased capsule edge by more than half a pixel
        const left = Math.round(capsule.x);
        const top = Math.round(capsule.y);
        const r = Qt.rect(left, top, Math.round(capsule.x + capsule.width) - left, Math.round(capsule.y + capsule.height) - top);
        if (r.x === sentBlurRect.x && r.y === sentBlurRect.y && r.width === sentBlurRect.width && r.height === sentBlurRect.height) {
            return;
        }
        sentBlurRect = r;
        WindowBlur.enable(root, r, r.height / 2);
        root.update();
    }

    onAfterAnimating: syncBlur()
    onFrameSwapped: syncBlur()

    // Target width; animates when the content changes while shown
    // Kept even so that the centered capsule (and the content layers in it)
    // rests on whole pixels
    property real capsuleWidth: Math.min(2 * Math.ceil(osd.implicitWidth / 2), maxCapsuleWidth)
    Behavior on capsuleWidth {
        enabled: root.reveal > 0
        NumberAnimation { id: widthAnimation; duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
    }

    Rectangle {
        id: capsule
        // Grows out of a small pill in the middle while revealing. The last
        // quarter of the way it collapses to nothing, so no blur is left
        // behind (an empty rect turns the blur off).
        readonly property real presence: Math.min(1, root.reveal / 0.25)
        // Far edge travels the full stretch, the near edge follows by 30%
        // of it, as if the whole capsule were tugged along
        readonly property real stretchPx: root.stretch
        readonly property real nearShift: 0.3 * stretchPx
        readonly property real growth: stretchPx - nearShift
        // Thins slightly while stretched
        width: (root.capsuleWidth * (0.6 + 0.4 * root.reveal) + growth) * presence
        height: (osd.implicitHeight * (0.7 + 0.3 * root.reveal) - 0.25 * stretchPx) * presence
        x: (root.width - width) / 2 + root.stretchDirection * (stretchPx + nearShift) / 2
        y: (root.height - height) / 2
        radius: height / 2
        opacity: root.reveal
        clip: true
        // Dense enough that white text stays readable over light windows
        color: Qt.rgba(0.07, 0.07, 0.08, 0.72)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.16)

        OsdItem {
            id: osd
            // Follows the animated capsule width, so the content slides with
            // the edges instead of jumping to its final place
            width: root.capsuleWidth
            height: implicitHeight
            anchors.centerIn: parent
            // Content moves with the near edge; the bar pulls out to the far one
            anchors.horizontalCenterOffset: -root.stretchDirection * capsule.growth / 2
            stretch: root.stretchDirection > 0 ? capsule.growth : 0
            scale: 0.85 + 0.15 * root.reveal
            // Morph text only while the capsule is on screen; a fresh OSD
            // just shows the new value
            morphEnabled: root.reveal > 0
            // Content sits on whole pixels at rest and only moves by
            // fractions during these animations
            moving: root.reveal < 1 || root.stretch !== 0 || widthAnimation.running
        }
    }
}
