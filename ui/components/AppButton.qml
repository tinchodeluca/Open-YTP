// ui/components/AppButton.qml
// Botón reutilizable themed — reemplaza todos los Rectangle+MouseArea sueltos
import QtQuick
import "../themes"

Rectangle {
    id: root

    // ── API pública ────────────────────────────────
    property string label:   ""
    property string icon:    ""           // emoji o carácter unicode
    property string variant: "default"    // "default" | "accent" | "danger" | "ghost"
    property bool   enabled: true

    signal clicked()

    // ── Tamaño ─────────────────────────────────────
    implicitWidth:  120
    implicitHeight: 36
    radius: ThemeManager.radiusMid

    // ── Colores según variante ─────────────────────
    color: {
        if (!enabled)               return ThemeManager.btnBg
        if (ma.containsMouse) {
            if (variant === "accent")  return ThemeManager.accentHover
            if (variant === "danger")  return ThemeManager.btnDangerHover
            return ThemeManager.btnHover
        }
        if (variant === "accent")   return ThemeManager.accent
        if (variant === "danger")   return ThemeManager.btnDanger
        if (variant === "ghost")    return "transparent"
        return ThemeManager.btnBg
    }

    border.color: {
        if (variant === "accent")   return ThemeManager.accentHover
        if (variant === "danger")   return ThemeManager.btnDangerHover
        if (variant === "ghost")    return ThemeManager.btnBorder
        return ThemeManager.btnBorder
    }
    border.width: variant === "ghost" ? 1 : 1
    opacity: enabled ? 1.0 : 0.4

    Behavior on color { ColorAnimation { duration: 150 } }

    // ── Glow para accent ───────────────────────────
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: "transparent"
        border.color: ThemeManager.accentGlow
        border.width: (variant === "accent" && ma.containsMouse) ? 6 : 0
        Behavior on border.width { NumberAnimation { duration: 200 } }
    }

    // ── Contenido ─────────────────────────────────
    Row {
        anchors.centerIn: parent
        spacing: 6

        Text {
            visible: root.icon !== ""
            text:    root.icon
            color:   root.variant === "accent" ? ThemeManager.textOnAccent : ThemeManager.textPrimary
            font.pixelSize: 14
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            visible: root.label !== ""
            text:    root.label
            color:   root.variant === "accent" ? ThemeManager.textOnAccent : ThemeManager.textPrimary
            font.pixelSize: 13
            font.family:    ThemeManager.fontFamily
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    // ── Interacción ────────────────────────────────
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape:  enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        enabled:      root.enabled
        onClicked:    root.clicked()
    }

    // ── Animación al presionar ────────────────────
    scale: ma.pressed ? 0.95 : 1.0
    Behavior on scale { NumberAnimation { duration: 80 } }
}

/*
 * ── Ejemplos de uso ────────────────────────────────────────────
 *
 *  AppButton { label: "Agregar"; icon: "＋"; variant: "accent";
 *              onClicked: doSomething() }
 *
 *  AppButton { label: "Eliminar"; variant: "danger";
 *              onClicked: removeSong() }
 *
 *  AppButton { icon: "▶"; variant: "accent"; implicitWidth: 42;
 *              onClicked: player.play() }
 */
