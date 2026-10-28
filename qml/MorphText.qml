/*
    Text that morphs per character when it changes: old characters blur
    out while the new ones blur in, with a small stagger between them.
    Each character is placed at the advance of its prefix, so kerning
    matches a plain Text.

    Words morph every character; numeric + alignRight morphs only the
    digits that changed, matched from the right edge, and the roll
    direction follows the value (up = new digits come from below).
*/

import QtQuick
import QtQuick.Effects

Item {
    id: morph

    property string text
    property font font
    property color color: "white"
    // Text.QtRendering / CurveRendering place glyphs at fractional
    // positions, so sliding text moves smoothly instead of in 1px steps
    property int renderType: Text.QtRendering
    property bool alignRight: false
    property bool numeric: false
    // Off: changes apply instantly (e.g. while the OSD is hidden)
    property bool animated: true
    property real maximumWidth: Infinity
    // Longer texts fall back to a plain elided Text
    property int slotCount: 40
    property int duration: 180
    property int stagger: 12

    FontMetrics {
        id: fm
        font: morph.font
    }

    readonly property real textWidth: fm.advanceWidth(text)
    readonly property bool fallback: text.length > slotCount || textWidth > maximumWidth

    implicitWidth: Math.ceil(Math.min(textWidth, maximumWidth))
    implicitHeight: Math.ceil(fm.height)

    property string previousText: ""

    function sync(animate) {
        const len = text.length;
        let dir = 1;
        if (numeric && previousText !== "") {
            dir = Number(text) >= Number(previousText) ? 1 : -1;
        }
        // Words change as a whole; digits only where they differ
        const force = !numeric && text !== previousText;
        let changed = 0;
        for (let i = 0; i < slotCount; ++i) {
            const slot = slots.itemAt(i);
            if (!slot) {
                continue;
            }
            const pos = alignRight ? len - 1 - i : i;
            const inside = pos >= 0 && pos < len;
            const ch = inside ? text[pos] : "";
            let x = slot.x;
            if (inside) {
                x = alignRight ? width - fm.advanceWidth(text.substring(pos))
                               : fm.advanceWidth(text.substring(0, pos));
            }
            // Vanishing characters go right away, the capsule is already shrinking
            const delay = ch === "" ? 0 : Math.min(changed, 10) * stagger;
            if (slot.apply(ch, x, delay, dir, animate, force)) {
                ++changed;
            }
        }
        previousText = text;
    }

    onTextChanged: sync(animated && visible && !fallback)
    // Only reposition here: the width may update before onTextChanged runs,
    // and a text change must not be applied without animation
    onWidthChanged: if (text === previousText) sync(false)
    onFallbackChanged: if (text === previousText) sync(false)
    Component.onCompleted: sync(false)

    Repeater {
        id: slots
        model: morph.slotCount

        delegate: Item {
            id: slot

            visible: !morph.fallback
            height: morph.height

            property string current: ""
            // 0 = previous character shown, 1 = new one settled
            property real t: 1
            property int dir: 1

            // Returns true if the character morphs. force: morph even if it
            // is the same character (whole-word changes)
            function apply(ch, nx, delay, dir, animate, force) {
                if (ch === current && !(force && ch !== "")) {
                    // Same character: slide to its new place
                    if (animate && ch !== "") {
                        moveAnimation.to = nx;
                        moveAnimation.restart();
                    } else if (ch !== "") {
                        moveAnimation.stop();
                        x = nx;
                    }
                    return false;
                }
                moveAnimation.stop();
                // The old character fades where it was, the new one appears in place
                outText.x = 0;
                if (ch !== "") {
                    if (current !== "") {
                        outText.x = x - nx;
                    }
                    x = nx;
                }
                outText.text = current;
                inText.text = ch;
                current = ch;
                slot.dir = dir;
                morphAnimation.stop();
                if (animate) {
                    t = 0;
                    pause.duration = delay;
                    morphAnimation.start();
                } else {
                    t = 1;
                }
                return true;
            }

            NumberAnimation {
                id: moveAnimation
                target: slot
                property: "x"
                duration: morph.duration
                easing.type: Easing.OutCubic
            }

            SequentialAnimation {
                id: morphAnimation
                PauseAnimation { id: pause }
                NumberAnimation {
                    target: slot
                    property: "t"
                    from: 0
                    to: 1
                    duration: morph.duration
                    easing.type: Easing.OutCubic
                }
            }

            // Outgoing character: slides away against the direction, blurs, fades
            Text {
                id: outText
                visible: text !== "" && slot.t < 1
                y: (slot.height - height) / 2 - slot.dir * slot.height * 0.5 * slot.t
                opacity: Math.max(0, 1 - slot.t * 1.8)
                scale: 1 - 0.3 * slot.t
                font: morph.font
                color: morph.color
                renderType: morph.renderType
                layer.enabled: visible
                layer.smooth: true
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blurMax: 8
                    blur: slot.t
                }
            }

            // Incoming character
            Text {
                id: inText
                y: (slot.height - height) / 2 + slot.dir * slot.height * 0.5 * (1 - slot.t)
                opacity: slot.t
                scale: 0.7 + 0.3 * slot.t
                font: morph.font
                color: morph.color
                renderType: morph.renderType
                layer.enabled: slot.t < 1
                layer.smooth: true
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blurMax: 8
                    blur: 1 - slot.t
                }
            }
        }
    }

    Text {
        visible: morph.fallback
        width: morph.width
        anchors.verticalCenter: parent.verticalCenter
        horizontalAlignment: morph.alignRight ? Text.AlignRight : Text.AlignLeft
        text: morph.text
        font: morph.font
        color: morph.color
        renderType: morph.renderType
        elide: Text.ElideRight
    }
}
