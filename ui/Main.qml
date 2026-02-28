import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia
import Qt.labs.platform
import QtQuick.Window
import OpenYTP 1.0
import "themes"    // ← ThemeManager singleton
import "components"

Window {
    id: mainWindow
    width: 360
    height: 680
    visible: true
    title: "Open-YTP ♪"
    color: "transparent"

    flags: Qt.FramelessWindowHint | Qt.Window | Qt.WindowStaysOnTopHint

    // ── Tamaños ────────────────────────────────────
    property real normalWidth:    360
    property real normalHeight:   680
    property real bookmarkWidth:  50
    property real bookmarkHeight: 180

    // ── Estado ────────────────────────────────────
    property bool isMinimizedMode:     false
    property real savedX:              0
    property real savedY:              0
    property bool firstMinimize:       true
    property bool isVerticalBookmark:  true

    // ═══════════════════════════════════════════════
    //  PlayerManager — toda la lógica de audio aquí
    // ═══════════════════════════════════════════════
    Item {
        id: playerManager
        property var  playlist:        []
        property int  currentIndex:    -1
        property bool isPlaying:       false
        property int  maxPlaylistSize: 50
        property int  playlistCount:   0
        property real currentPosition: 0
        property real currentDuration: 0

        property alias volume:      audioOutput.volume
        property alias mediaPlayer: player

        function getPosition()   { return currentPosition }
        function getDuration()   { return currentDuration }
        function canAddMore()    { return playlistCount < maxPlaylistSize }
        function getRemainingSlots() { return maxPlaylistSize - playlistCount }

        function seek(pos) {
            player.position = pos
            currentPosition = pos
        }

        function seekRelative(ms) {
            if (currentIndex < 0) return
            var p = Math.max(0, Math.min(player.position + ms, player.duration))
            seek(p)
        }

        function getCurrentSongName() {
            return (currentIndex >= 0 && currentIndex < playlistCount)
                   ? playlist[currentIndex].name.replace(/\.[^/.]+$/, "")
                   : "Title"
        }

        function playSong(index) {
            if (index >= 0 && index < playlistCount) {
                currentIndex = index
                player.stop()
                player.source = playlist[index].url
                player.play()
            }
        }

        function togglePlayPause() {
            if (playlistCount === 0) return
            if (currentIndex < 0) { playSong(0); return }
            if (isPlaying) player.pause()
            else           player.play()
        }

        function nextSong() {
            if (currentIndex < playlistCount - 1) playSong(currentIndex + 1)
            else { player.stop(); isPlaying = false }
        }

        function previousSong() {
            if (player.position > 3000) player.position = 0
            else if (currentIndex > 0)  playSong(currentIndex - 1)
        }

        function addFiles(files) {
            var temp = playlist
            for (var i = 0; i < files.length; i++) {
                if (temp.length >= maxPlaylistSize) break
                var url  = files[i].toString()
                var name = decodeURIComponent(url.split('/').pop())
                temp.push({ url: url, name: name })
            }
            playlist = temp
            playlistCount = playlist.length
            if (currentIndex < 0 && playlistCount > 0) playSong(0)
        }

        function addStreamToPlaylist(url, title, author, isFromPlaylist) {
            if (!canAddMore()) return
            var name = (title ? title.replace(".mp3", "") : "YouTube Stream") +
                       (author ? " — " + author : " — YouTube")
            var temp = playlist
            var pos  = (isFromPlaylist === true)
                       ? temp.length
                       : (currentIndex >= 0 ? currentIndex + 1 : temp.length)
            temp.splice(pos, 0, { url: url.toString(), name: name })
            playlist = temp
            playlistCount = playlist.length
            if (currentIndex < 0) playSong(0)
        }

        function removeSong(index) {
            if (index < 0 || index >= playlist.length) return
            var temp = playlist
            temp.splice(index, 1)
            playlist = temp
            playlistCount = playlist.length
            if (index === currentIndex) {
                if (playlist.length > 0) playSong(Math.min(index, playlist.length - 1))
                else { player.stop(); currentIndex = -1; isPlaying = false }
            } else if (index < currentIndex) {
                currentIndex--
            }
        }

        function moveSong(from, to) {
            if (from === to || from < 0 || to < 0 ||
                from >= playlist.length || to >= playlist.length) return
            var temp = playlist.slice()
            var song = temp.splice(from, 1)[0]
            temp.splice(to, 0, song)
            var ni = currentIndex
            if      (currentIndex === from)                        ni = to
            else if (from < currentIndex && to >= currentIndex)    ni--
            else if (from > currentIndex && to <= currentIndex)    ni++
            playlist = temp
            currentIndex = ni
            playlistCount = playlist.length
        }

        // ── MediaPlayer ────────────────────────────
        MediaPlayer {
            id: player
            audioOutput: AudioOutput { id: audioOutput; volume: 0.7 }
            onDurationChanged:     { playerManager.currentDuration = duration }
            onPositionChanged:     { playerManager.currentPosition = position }
            onPlaybackStateChanged:{
                playerManager.isPlaying = (playbackState === MediaPlayer.PlayingState)
            }
            onMediaStatusChanged: {
                if (mediaStatus === MediaPlayer.EndOfMedia)
                    Qt.callLater(playerManager.nextSong)
            }
            onErrorOccurred: function(error, errorString) {
                console.log("❌ Error:", errorString)
                Qt.callLater(playerManager.nextSong)
            }
        }
    }

    // ═══════════════════════════════════════════════
    //  Fondo con gradiente themed
    // ═══════════════════════════════════════════════
    Rectangle {
        anchors.fill: parent
        radius: 16
        gradient: Gradient {
            GradientStop { position: 0.0; color: ThemeManager.gradStart }
            GradientStop { position: 0.5; color: ThemeManager.gradMid   }
            GradientStop { position: 1.0; color: ThemeManager.gradEnd   }
        }
        border.color: ThemeManager.border
        border.width: 1
        visible: !isMinimizedMode
    }

    // ═══════════════════════════════════════════════
    //  Barra de título (arrastrar + controles)
    // ═══════════════════════════════════════════════
    Rectangle {
        id: titleBar
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 44
        color: "transparent"
        radius: 16
        z: 100
        visible: !isMinimizedMode

        // Drag
        MouseArea {
            anchors.fill: parent
            property point last: Qt.point(0, 0)
            onPressed:         last = Qt.point(mouseX, mouseY)
            onPositionChanged: if (pressed) {
                mainWindow.x += mouseX - last.x
                mainWindow.y += mouseY - last.y
            }
        }

        // Selector de theme
        Row {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            anchors.leftMargin: 12
            spacing: 6

            Repeater {
                model: [
                    { id: "dark",   dot: "#5eead4" },
                    { id: "light",  dot: "#6366f1" },
                    { id: "pastel", dot: "#f0abfc" },
                    { id: "amoled", dot: "#00ff88" }
                ]

                Rectangle {
                    width: 14; height: 14; radius: 7
                    color: modelData.dot
                    opacity: ThemeManager.current === modelData.id ? 1.0 : 0.35
                    scale:   ThemeManager.current === modelData.id ? 1.2 : 1.0

                    Behavior on opacity { NumberAnimation { duration: 200 } }
                    Behavior on scale   { NumberAnimation { duration: 150 } }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ThemeManager.current = modelData.id
                    }

                    // Tooltip
                    ToolTip.visible: hovered
                    ToolTip.text:    modelData.id
                    property alias hovered: hoverArea.containsMouse
                    MouseArea { id: hoverArea; anchors.fill: parent; hoverEnabled: true }
                }
            }
        }

        // Botones minimize / close
        Row {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            anchors.rightMargin: 10
            spacing: 8

            // Minimizar
            Rectangle {
                width: 30; height: 30; radius: 15
                color: minArea.containsMouse ? ThemeManager.btnHover : ThemeManager.btnBg
                border.color: ThemeManager.btnBorder; border.width: 1

                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    anchors.centerIn: parent
                    text: "−"; color: ThemeManager.textPrimary
                    font.pixelSize: 18; font.bold: true
                }
                MouseArea {
                    id: minArea; anchors.fill: parent
                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: minimizeToBookmark()
                }
            }

            // Cerrar
            Rectangle {
                width: 30; height: 30; radius: 15
                color: closeArea.containsMouse ? ThemeManager.btnDangerHover : ThemeManager.btnBg
                border.color: closeArea.containsMouse ? ThemeManager.btnDangerHover : ThemeManager.btnBorder
                border.width: 1

                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    anchors.centerIn: parent
                    text: "×"; color: ThemeManager.textPrimary
                    font.pixelSize: 20; font.bold: true
                }
                MouseArea {
                    id: closeArea; anchors.fill: parent
                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: Qt.quit()
                }
            }
        }
    }

    // ═══════════════════════════════════════════════
    //  Mini-player (bookmark mode)
    // ═══════════════════════════════════════════════
    Rectangle {
        id: bookmarkMode
        anchors.fill: parent
        visible: isMinimizedMode
        radius: 8
        z: 200
        color: ThemeManager.bookmarkBg
        border.color: ThemeManager.bookmarkBorder
        border.width: 2

        MouseArea {
            anchors.fill: parent
            property point dragStart: Qt.point(0, 0)
            cursorShape: Qt.SizeAllCursor
            onPressed:         dragStart = Qt.point(mouse.x, mouse.y)
            onPositionChanged: if (pressed) {
                mainWindow.x += mouse.x - dragStart.x
                mainWindow.y += mouse.y - dragStart.y
            }
            onReleased:     snapToEdge()
            onDoubleClicked: restoreWindow()
        }

        // Vertical
        ColumnLayout {
            anchors { fill: parent; margins: 6 }
            spacing: 6
            visible: isVerticalBookmark

            MiniBtn { icon: playerManager.isPlaying ? "▶" : "⏸"; active: playerManager.isPlaying
                      onTap: playerManager.togglePlayPause() }
            MiniBtn { icon: "|◄"; onTap: playerManager.previousSong() }
            MiniBtn { icon: "►|"; onTap: playerManager.nextSong() }
            MiniBtn { icon: "□";  onTap: restoreWindow() }
        }

        // Horizontal
        RowLayout {
            anchors { fill: parent; margins: 6 }
            spacing: 6
            visible: !isVerticalBookmark

            MiniBtn { icon: "□";  onTap: restoreWindow() }
            MiniBtn { icon: "|◄"; onTap: playerManager.previousSong() }
            MiniBtn { icon: "►|"; onTap: playerManager.nextSong() }
            MiniBtn { icon: playerManager.isPlaying ? "▶" : "⏸"; active: playerManager.isPlaying
                      onTap: playerManager.togglePlayPause() }
        }
    }

    // ═══════════════════════════════════════════════
    //  Contenido principal
    // ═══════════════════════════════════════════════
    Item {
        anchors { fill: parent; margins: 16 }
        visible: !isMinimizedMode
        z: 50

        PlayerCard {
            id: playerCard
            anchors.fill: parent
            playerManager: playerManager
        }
    }

    QueueDrawer {
        id: queueDrawer
        y: 16
        height: mainWindow.height - 32
        playerManager: playerManager
        z: 300
        visible: !isMinimizedMode
    }

    Connections {
        target: playerCard
        function onAddFilesRequested() { fileDialog.open() }
    }

    FileDialog {
        id: fileDialog
        title: "Seleccionar archivos de audio"
        nameFilters: ["Audio (*.mp3 *.wav *.m4a *.ogg *.flac)"]
        fileMode: FileDialog.OpenFiles
        onAccepted: playerManager.addFiles(fileDialog.files)
    }

    // ═══════════════════════════════════════════════
    //  Funciones de ventana
    // ═══════════════════════════════════════════════
    function minimizeToBookmark() {
        savedX = mainWindow.x; savedY = mainWindow.y
        isMinimizedMode = true

        var scr = screenAt(mainWindow.x + mainWindow.width/2, mainWindow.y + mainWindow.height/2)

        if (firstMinimize) {
            isVerticalBookmark = false
            mainWindow.height = bookmarkWidth
            mainWindow.width  = bookmarkHeight
            mainWindow.x = scr.virtualX + scr.width - bookmarkHeight - 10
            mainWindow.y = scr.virtualY + 10
            firstMinimize = false
        } else {
            snapToEdge()
        }
    }

    function restoreWindow() {
        isMinimizedMode = false
        mainWindow.width  = normalWidth
        mainWindow.height = normalHeight
        mainWindow.x = savedX
        mainWindow.y = savedY
    }

    function screenAt(x, y) {
        var s = Qt.application.screens[0]
        for (var i = 0; i < Qt.application.screens.length; i++) {
            var sc = Qt.application.screens[i]
            if (x >= sc.virtualX && x < sc.virtualX + sc.width &&
                y >= sc.virtualY && y < sc.virtualY + sc.height) {
                s = sc; break
            }
        }
        return s
    }

    function snapToEdge() {
        var cx  = mainWindow.x + mainWindow.width  / 2
        var cy  = mainWindow.y + mainWindow.height / 2
        var scr = screenAt(cx, cy)

        var dL = cx - scr.virtualX
        var dR = (scr.virtualX + scr.width)  - cx
        var dT = cy - scr.virtualY
        var dB = (scr.virtualY + scr.height) - cy
        var m  = Math.min(dL, dR, dT, dB)

        if      (m === dL) { isVerticalBookmark = true;  mainWindow.width = bookmarkWidth;  mainWindow.height = bookmarkHeight; mainWindow.x = scr.virtualX }
        else if (m === dR) { isVerticalBookmark = true;  mainWindow.width = bookmarkWidth;  mainWindow.height = bookmarkHeight; mainWindow.x = scr.virtualX + scr.width - bookmarkWidth }
        else if (m === dT) { isVerticalBookmark = false; mainWindow.height = bookmarkWidth; mainWindow.width = bookmarkHeight;  mainWindow.y = scr.virtualY }
        else               { isVerticalBookmark = false; mainWindow.height = bookmarkWidth; mainWindow.width = bookmarkHeight;  mainWindow.y = scr.virtualY + scr.height - bookmarkWidth }

        mainWindow.x = Math.max(scr.virtualX, Math.min(scr.virtualX + scr.width  - mainWindow.width,  mainWindow.x))
        mainWindow.y = Math.max(scr.virtualY, Math.min(scr.virtualY + scr.height - mainWindow.height, mainWindow.y))
    }

    // ── Componente auxiliar para el mini-player ───
    component MiniBtn: Rectangle {
        property string  icon:   ""
        property bool    active: false
        signal tapped()
        signal tap()

        Layout.alignment: Qt.AlignHCenter
        width: 30; height: 30; radius: 15
        color:        active          ? ThemeManager.accent    :
                      ma.containsMouse ? ThemeManager.btnHover  : ThemeManager.btnBg
        border.color: active ? ThemeManager.accentHover : ThemeManager.btnBorder
        border.width: active ? 2 : 1

        Behavior on color { ColorAnimation { duration: 150 } }

        Text {
            anchors.centerIn: parent
            text:             parent.icon
            color:            parent.active ? ThemeManager.textOnAccent : ThemeManager.textMuted
            font.pixelSize:   10
            font.bold:        true
        }

        MouseArea {
            id: ma; anchors.fill: parent
            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: { parent.tapped(); parent.tap() }
        }

        // alias para onTap
        function onTap(fn) {}
    }
}
