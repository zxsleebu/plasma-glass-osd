/*
    Content of the glass capsule OSD: icon, gradient bar and value,
    or icon and text. Keyboard layouts get a short code chip ("EN").

    Elements are placed by hand instead of a RowLayout so that switching
    between OSD kinds can flow: the accent bar fill turns into the layout
    chip, the icon blurs into the new one, the number and the label morph
    out and in character by character, and everything slides into place.
*/

import QtQuick
import QtQuick.Effects
import org.kde.kirigami as Kirigami

Item {
    id: root

    // OSD Timeout in msecs - how long it will stay on the screen
    property int timeout: 1800
    // Text, or a number for the progress bar when showingProgress is set
    property var osdValue
    property int osdMaxValue: 100
    // Additional text if showingProgress is set to true
    property string osdAdditionalText: ""
    property string icon
    property bool showingProgress: false

    // System accent color, fading to a lighter, slightly hue-shifted tint
    property color accentFrom: Kirigami.Theme.highlightColor
    readonly property color accentTo: Qt.hsla((accentFrom.hslHue + 0.08) % 1, accentFrom.hslSaturation,
                                              Math.min(accentFrom.hslLightness + 0.15, 0.85), 1)
    readonly property bool isKeyboardLayout: !showingProgress && (icon === "keyboard-layout" || icon.startsWith("input-keyboard"))
    readonly property string text: (showingProgress ? osdAdditionalText : osdValue) ?? ""

    // "English (US)" -> "EN", "Russian" -> "RU"
    readonly property string layoutCode: {
        const codes = {
            "english": "EN", "russian": "RU", "ukrainian": "UA", "german": "DE",
            "french": "FR", "spanish": "ES", "polish": "PL", "belarusian": "BY",
            "japanese": "JA", "kazakh": "KZ", "czech": "CZ", "italian": "IT",
        };
        const word = String(root.text).split(/[\s(]/)[0].toLowerCase();
        return codes[word] ?? word.slice(0, 2).toUpperCase();
    }

    // Light icons and text on the dark glass
    Kirigami.Theme.colorSet: Kirigami.Theme.Complementary
    Kirigami.Theme.inherit: false

    // Morphing and sliding on changes; Osd turns it off while hidden
    property bool morphEnabled: true
    // Set while the content is moved by fractions of a pixel
    property bool moving: false

    property string fontFamily: "Readex Pro"
    property int fontWeight: Font.Medium

    readonly property int moveDuration: 260

    // Rubber-band pull at the volume limit, px: the bar gets longer and
    // everything after it moves along (set by Osd)
    property real stretch: 0
    readonly property real barScale: showingProgress ? (trackWidth + stretch) / trackWidth : 1

    // Layout for the target state; the items animate towards it
    readonly property int leftMargin: 14
    readonly property int rightMargin: 18
    readonly property int spacing: 10
    readonly property int trackWidth: 150
    readonly property real progress: Math.max(0, Math.min(1, Number(osdValue) / osdMaxValue))

    readonly property real contentX: leftMargin + (iconItem.valid ? 18 + spacing : 0)
    readonly property real valueX: contentX + trackWidth + spacing
    readonly property real valueWidth: Math.ceil(valueMetrics.advanceWidth)
    readonly property real chipWidth: chipLabel.implicitWidth + 16
    readonly property real chipHeight: chipLabel.implicitHeight + 2
    readonly property bool showLabel: text !== ""
    // An empty label waits next to the chip, so a layout name appearing
    // there does not fly in from the far end of the bar
    readonly property real labelX: showingProgress && showLabel ? valueX + valueWidth + spacing
                                 : isKeyboardLayout || showingProgress ? contentX + chipWidth + spacing
                                 : contentX
    readonly property real contentRight: showLabel ? labelX + label.implicitWidth
                                       : showingProgress ? valueX + valueWidth
                                       : isKeyboardLayout ? contentX + chipWidth
                                       : contentX - (iconItem.valid ? spacing : 0)

    implicitWidth: Math.ceil(contentRight + rightMargin)
    implicitHeight: 40

    TextMetrics {
        id: valueMetrics
        text: String(root.osdMaxValue)
        font: valueText.font
    }

    // Icon: the old one blurs out while the new one blurs in.
    // Kirigami.Icon aligns itself to the screen pixel grid, so on its own
    // it moves in 1px steps. While the content moves it is rendered into a
    // layer drawn with smooth filtering at fractional positions; at rest
    // (always on whole pixels) it is drawn directly and stays crisp, since
    // a 1px-line icon at a half-pixel offset is unavoidably soft.
    // 4px of margin keeps the blur inside the layer.
    Item {
        id: iconItem
        readonly property bool valid: iconA.valid || iconB.valid
        x: root.leftMargin - 4
        y: Math.round((root.height - 18) / 2) - 4
        width: 26
        height: 26
        layer.enabled: root.moving
        layer.smooth: true

        property bool showingA: true
        property real t: 1

        function swap() {
            const incoming = showingA ? iconB : iconA;
            incoming.source = root.icon;
            showingA = !showingA;
            iconAnimation.stop();
            if (root.morphEnabled) {
                t = 0;
                iconAnimation.start();
            } else {
                t = 1;
            }
        }

        Connections {
            target: root
            function onIconChanged() { iconItem.swap(); }
        }
        Component.onCompleted: iconA.source = root.icon

        NumberAnimation {
            id: iconAnimation
            target: iconItem
            property: "t"
            from: 0
            to: 1
            duration: root.moveDuration
            easing.type: Easing.OutCubic
        }

        Kirigami.Icon {
            id: iconA
            anchors.centerIn: parent
            width: 18
            height: 18
            animated: false
            readonly property real k: iconItem.showingA ? iconItem.t : 1 - iconItem.t
            opacity: k
            scale: 0.6 + 0.4 * k
            layer.enabled: k < 1
            layer.smooth: true
            layer.effect: MultiEffect { blurEnabled: true; blurMax: 8; blur: 1 - iconA.k }
        }
        Kirigami.Icon {
            id: iconB
            anchors.centerIn: parent
            width: 18
            height: 18
            animated: false
            readonly property real k: iconItem.showingA ? 1 - iconItem.t : iconItem.t
            opacity: k
            scale: 0.6 + 0.4 * k
            layer.enabled: k < 1
            layer.smooth: true
            layer.effect: MultiEffect { blurEnabled: true; blurMax: 8; blur: 1 - iconB.k }
        }
    }

    // Bar background; folds into the chip shape and fades out with progress mode
    Rectangle {
        id: track
        x: root.contentX
        y: (root.height - height) / 2
        width: root.showingProgress ? root.trackWidth : root.chipWidth
        height: root.showingProgress ? 6 : root.chipHeight
        radius: height / 2
        color: Qt.rgba(1, 1, 1, 0.22)
        opacity: root.showingProgress ? 1 : 0
        transform: Scale { xScale: root.barScale }

        Behavior on x { enabled: root.morphEnabled; NumberAnimation { duration: root.moveDuration; easing.type: Easing.OutCubic } }
        Behavior on width { enabled: root.morphEnabled; NumberAnimation { duration: root.moveDuration; easing.type: Easing.OutCubic } }
        Behavior on height { enabled: root.morphEnabled; NumberAnimation { duration: root.moveDuration; easing.type: Easing.OutCubic } }
        Behavior on opacity { enabled: root.morphEnabled; NumberAnimation { duration: root.moveDuration } }
    }

    // Accent shape: the bar fill in progress mode, the code chip for layouts
    Rectangle {
        id: accent
        x: root.contentX
        y: (root.height - height) / 2
        width: root.showingProgress ? root.trackWidth * root.progress
             : root.isKeyboardLayout ? root.chipWidth : 0
        height: root.showingProgress ? 6 : root.chipHeight
        radius: height / 2
        opacity: root.showingProgress || root.isKeyboardLayout ? 1 : 0
        transform: Scale { xScale: root.barScale }
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: root.accentFrom }
            GradientStop { position: 1; color: root.accentTo }
        }

        Behavior on x { enabled: root.morphEnabled; NumberAnimation { duration: root.moveDuration; easing.type: Easing.OutCubic } }
        Behavior on width { enabled: root.morphEnabled; NumberAnimation { duration: root.moveDuration; easing.type: Easing.OutCubic } }
        Behavior on height { enabled: root.morphEnabled; NumberAnimation { duration: root.moveDuration; easing.type: Easing.OutCubic } }
        Behavior on opacity { enabled: root.morphEnabled; NumberAnimation { duration: root.moveDuration } }

        // Layout code; blurs in while the bar turns into a chip
        MorphText {
            id: chipLabel
            anchors.centerIn: parent
            slotCount: 4
            animated: root.morphEnabled
            text: root.isKeyboardLayout ? root.layoutCode : ""
            font.pixelSize: 12
            font.family: root.fontFamily
            font.weight: Font.Bold
            color: Kirigami.Theme.highlightedTextColor
        }
    }

    // Digits roll up or down with the value
    MorphText {
        id: valueText
        x: root.valueX
        y: Math.round((root.height - height) / 2)
        width: root.valueWidth
        alignRight: true
        numeric: true
        transform: Translate { x: root.stretch }
        slotCount: 4
        animated: root.morphEnabled
        text: root.showingProgress ? String(Number(root.osdValue)) : ""
        font.pixelSize: 13
        font.family: root.fontFamily
        font.weight: root.fontWeight
        font.features: { "tnum": 1 }
        // Hint at volume above 100%
        color: Number(root.osdValue) > 125 ? "#ff8a8a" : Number(root.osdValue) > 100 ? "#ffd27a" : "white"
        Behavior on color {
            ColorAnimation { duration: 200 }
        }
    }

    // Plain text OSDs (layout name, "Muted", etc.); also the label next to a bar
    MorphText {
        id: label
        x: root.labelX
        y: Math.round((root.height - height) / 2)
        maximumWidth: 360
        slotCount: 48
        transform: Translate { x: root.showingProgress ? root.stretch : 0 }
        animated: root.morphEnabled
        text: root.text
        font.pixelSize: 13
        font.family: root.fontFamily
        font.weight: root.fontWeight
        color: "white"

        Behavior on x { enabled: root.morphEnabled; NumberAnimation { duration: root.moveDuration; easing.type: Easing.OutCubic } }
    }
}
