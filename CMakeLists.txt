cmake_minimum_required(VERSION 3.16)
project(OpenYTP VERSION 1.0 LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 6.10 REQUIRED COMPONENTS
    Core
    Gui
    Qml
    Quick
    QuickControls2
    Multimedia
)
qt_standard_project_setup()

# ─────────────────────────────────────────────────────
#  Fuentes C++
# ─────────────────────────────────────────────────────
set(SRC
    src/main.cpp
    src/audiocaptureanalyzer.cpp
    src/youtubedownloader.cpp
)
set(HEADERS
    src/audiocaptureanalyzer.h
    src/youtubedownloader.h
)

# ─────────────────────────────────────────────────────
#  Archivos QML
# ─────────────────────────────────────────────────────
set(QML_FILES
    ui/Main.qml

    # Componentes de UI
    ui/components/ActionButtons.qml
    ui/components/AudioVisualizer.qml
    ui/components/BookmarkPlayer.qml
    ui/components/PlayerCard.qml
    ui/components/PlayerControls.qml
    ui/components/ProgressBar.qml
    ui/components/SongInfo.qml
    ui/components/VisualizerBar.qml
    ui/components/VisualizerBars.qml
    ui/components/VolumeControl.qml
    ui/components/YoutubeQueueInput.qml
    ui/components/QueueDrawer.qml

    # Themes
    ui/themes/ThemeManager.qml
)

# ─────────────────────────────────────────────────────
#  Recursos (íconos, imágenes)
# ─────────────────────────────────────────────────────
set(RESOURCE_FILES
    resources/pink.png
    resources/pink.ico
)

# ─────────────────────────────────────────────────────
#  ThirdParty headers
# ─────────────────────────────────────────────────────
file(GLOB THIRD_PARTY_HEADERS "${CMAKE_CURRENT_SOURCE_DIR}/thirdparty/*.h")
source_group(TREE "${CMAKE_CURRENT_SOURCE_DIR}/thirdparty" PREFIX "ThirdParty" FILES ${THIRD_PARTY_HEADERS})

# ─────────────────────────────────────────────────────
#  Ejecutable
# ─────────────────────────────────────────────────────
qt_add_executable(OpenYTP
    ${SRC}
    ${HEADERS}
    ${THIRD_PARTY_HEADERS}
)

if(WIN32)
    set_target_properties(OpenYTP PROPERTIES WIN32_EXECUTABLE TRUE)
    set(ICON_RC "${CMAKE_CURRENT_BINARY_DIR}/icon.rc")
    file(WRITE ${ICON_RC} "IDI_ICON1 ICON DISCARDABLE \"${CMAKE_CURRENT_SOURCE_DIR}/resources/pink.ico\"\n")
    target_sources(OpenYTP PRIVATE ${ICON_RC})
endif()

target_include_directories(OpenYTP PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/src
    ${CMAKE_CURRENT_SOURCE_DIR}/thirdparty
)

# ─────────────────────────────────────────────────────
#  Módulo QML — Debug (hot reload) vs Release
# ─────────────────────────────────────────────────────
if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    message(STATUS "🔥 DEBUG: hot reload habilitado")
    add_compile_definitions(QT_QML_DEBUG)

    qt_add_qml_module(OpenYTP
        URI OpenYTP
        VERSION 1.0
        QML_FILES ${QML_FILES}
        NO_RESOURCE_TARGET_PATH
    )

    foreach(QML_FILE ${QML_FILES})
        get_filename_component(QML_FILE_DIR ${QML_FILE} DIRECTORY)
        if(QML_FILE_DIR)
            add_custom_command(TARGET OpenYTP POST_BUILD
                COMMAND ${CMAKE_COMMAND} -E make_directory
                    "$<TARGET_FILE_DIR:OpenYTP>/${QML_FILE_DIR}"
            )
        endif()
        add_custom_command(TARGET OpenYTP POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "${CMAKE_CURRENT_SOURCE_DIR}/${QML_FILE}"
                "$<TARGET_FILE_DIR:OpenYTP>/${QML_FILE}"
            COMMENT "Hot reload: copiando ${QML_FILE}"
        )
    endforeach()
else()
    message(STATUS "📦 RELEASE: QML empaquetado en recursos")
    qt_add_qml_module(OpenYTP
        URI OpenYTP
        VERSION 1.0
        QML_FILES ${QML_FILES}
    )
endif()

# ─────────────────────────────────────────────────────
#  Recursos Qt
# ─────────────────────────────────────────────────────
qt_add_resources(OpenYTP "resources"
    PREFIX "/"
    FILES ${RESOURCE_FILES}
)

# ─────────────────────────────────────────────────────
#  Librerías
# ─────────────────────────────────────────────────────
add_library(miniaudio INTERFACE)
target_include_directories(miniaudio INTERFACE
    ${CMAKE_CURRENT_SOURCE_DIR}/thirdparty
)

target_link_libraries(OpenYTP PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::Multimedia
    miniaudio
)

# ─────────────────────────────────────────────────────
#  Copiar yt-dlp.exe al build (solo Windows)
# ─────────────────────────────────────────────────────
if(WIN32)
    if(EXISTS "${CMAKE_SOURCE_DIR}/thirdparty/yt-dlp.exe")
        add_custom_command(TARGET OpenYTP POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "${CMAKE_SOURCE_DIR}/thirdparty/yt-dlp.exe"
                "$<TARGET_FILE_DIR:OpenYTP>/yt-dlp.exe"
            COMMENT "Copiando yt-dlp.exe"
        )
    else()
        message(STATUS "yt-dlp.exe no encontrado — se descargará automáticamente")
    endif()
endif()
