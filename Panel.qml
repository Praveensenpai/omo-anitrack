import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "paisen.omo-anitrack"
  ipcTarget: "paisen.omo-anitrack"

  property var scheduleData: ({})
  property string selectedTab: (scheduleData && scheduleData.pinnedCount > 0) ? "pinned" : "all"
  property string dayFilter: "today" // "today", "tomorrow", "this_week", "all"
  property int currentTimestamp: Math.floor(Date.now() / 1000)

  readonly property var shows: (scheduleData && scheduleData.shows) ? scheduleData.shows : []
  readonly property int todayCount: (scheduleData && scheduleData.todayCount) ? scheduleData.todayCount : 0
  readonly property int pinnedCount: (scheduleData && scheduleData.pinnedCount) ? scheduleData.pinnedCount : 0
  readonly property int pinnedTodayCount: (scheduleData && scheduleData.pinnedTodayCount) ? scheduleData.pinnedTodayCount : 0
  readonly property var nextAiring: (scheduleData && scheduleData.nextAiring) ? scheduleData.nextAiring : null

  readonly property string barIconText: "🎌" + (pinnedTodayCount > 0 ? (" " + pinnedTodayCount) : "")
  readonly property string barTooltip: pinnedTodayCount > 0
    ? ("Omo Anitrack: " + pinnedTodayCount + " pinned anime airing today")
    : ("Omo Anitrack: " + todayCount + " anime airing today")

  readonly property string fetchScriptPath: Qt.resolvedUrl("fetch.sh").toString().replace("file://", "")
  readonly property string actionScriptPath: Qt.resolvedUrl("action.sh").toString().replace("file://", "")
  readonly property string cacheFilePath: "file://" + Quickshell.env("HOME") + "/.cache/omarchy/anitrack_schedule.json"

  function formatCountdown(airingAt) {
    var diff = airingAt - root.currentTimestamp
    if (diff <= 0) {
      var passed = Math.abs(diff)
      if (passed < 3600) return "Aired " + Math.floor(passed / 60) + "m ago"
      if (passed < 86400) return "Aired " + Math.floor(passed / 3600) + "h ago"
      return "Aired"
    }
    var hours = Math.floor(diff / 3600)
    var minutes = Math.floor((diff % 3600) / 60)
    if (hours === 0) return "In " + minutes + "m"
    if (hours < 24) return "In " + hours + "h " + (minutes > 0 ? (minutes + "m") : "")
    var days = Math.floor(hours / 24)
    return "In " + days + "d " + (hours % 24) + "h"
  }

  function getFilteredShows() {
    var list = root.shows || []
    if (root.selectedTab === "pinned") {
      return list.filter(function(item) { return item.pinned === true })
    }
    if (root.dayFilter === "all") {
      return list
    }
    return list.filter(function(item) { return item.dayGroup === root.dayFilter })
  }

  function reloadData() {
    fileReader.read()
  }

  function triggerAction(actionName, arg) {
    if (arg !== undefined && arg !== null) {
      actionProc.command = [root.actionScriptPath, actionName, String(arg)]
    } else {
      actionProc.command = [root.actionScriptPath, actionName]
    }
    actionProc.running = true
  }

  onOpenedChanged: {
    if (opened) {
      root.currentTimestamp = Math.floor(Date.now() / 1000)
      reloadData()
      // Refresh if no data or cache older than 30m
      if (!root.shows || root.shows.length === 0) {
        root.triggerAction("refresh")
      }
    }
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  // Read cached JSON file
  FileView {
    id: fileReader
    path: root.cacheFilePath
    onLoaded: {
      try {
        var parsed = JSON.parse(text())
        if (parsed && parsed.shows) {
          root.scheduleData = parsed
        }
      } catch (e) {
        // Fallback gracefully on parsing error
      }
    }
  }

  Process {
    id: actionProc
    onRunningChanged: {
      if (!running) {
        fileReader.read()
      }
    }
  }

  // Ticks locally every 30s to update countdown text accurately
  Timer {
    interval: 30000
    running: true
    repeat: true
    onTriggered: {
      root.currentTimestamp = Math.floor(Date.now() / 1000)
    }
  }

  // Background fetch every 30 minutes
  Timer {
    interval: 1800000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      root.triggerAction("refresh")
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.barIconText
    slotSize: Style.bar.iconSlot
    tooltipText: root.barTooltip
    onPressed: function(b) {
      if (b === Qt.RightButton || b === Qt.MiddleButton) {
        root.triggerAction("refresh")
      } else {
        root.toggle()
      }
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(420))
    contentHeight: panel.fittedContentHeight(Style.space(520))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()

      Column {
        id: mainColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        spacing: Style.space(10)

        // ---------- Hero Header ----------
        Item {
          width: parent.width
          implicitHeight: Style.space(38)

          Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(10)

            Text {
              text: "🎌"
              font.pixelSize: Style.font.title
              anchors.verticalCenter: parent.verticalCenter
            }

            Column {
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(1)

              Text {
                text: "Omo Anitrack"
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.title
                font.bold: true
              }

              Text {
                text: "AIRING SCHEDULE & WATCHLIST"
                color: Qt.darker(root.bar.foreground, 1.4)
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 1.1
              }
            }
          }

          // Refresh Button
          Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(32)
            height: Style.space(32)
            radius: Style.space(6)
            color: refreshArea.containsMouse
              ? Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.15)
              : Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.06)

            Text {
              anchors.centerIn: parent
              text: "󰑐"
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.body
            }

            MouseArea {
              id: refreshArea
              anchors.fill: parent
              hoverEnabled: true
              onClicked: {
                root.triggerAction("refresh")
              }
            }
          }
        }

        // ---------- Tabs (Pinned vs All) ----------
        Row {
          width: parent.width
          spacing: Style.space(8)

          // Pinned Tab Button
          Rectangle {
            width: (parent.width - Style.space(8)) / 2
            height: Style.space(34)
            radius: Style.space(6)
            color: root.selectedTab === "pinned"
              ? Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.20)
              : (pinnedTabArea.containsMouse
                  ? Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.10)
                  : Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.05))

            Row {
              anchors.centerIn: parent
              spacing: Style.space(6)

              Text {
                text: "⭐"
                font.pixelSize: Style.font.caption
              }

              Text {
                text: "Pinned (" + root.pinnedCount + ")"
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: root.selectedTab === "pinned"
              }
            }

            MouseArea {
              id: pinnedTabArea
              anchors.fill: parent
              hoverEnabled: true
              onClicked: root.selectedTab = "pinned"
            }
          }

          // All Tab Button
          Rectangle {
            width: (parent.width - Style.space(8)) / 2
            height: Style.space(34)
            radius: Style.space(6)
            color: root.selectedTab === "all"
              ? Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.20)
              : (allTabArea.containsMouse
                  ? Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.10)
                  : Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.05))

            Row {
              anchors.centerIn: parent
              spacing: Style.space(6)

              Text {
                text: "🌐"
                font.pixelSize: Style.font.caption
              }

              Text {
                text: "All Shows (" + root.shows.length + ")"
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: root.selectedTab === "all"
              }
            }

            MouseArea {
              id: allTabArea
              anchors.fill: parent
              hoverEnabled: true
              onClicked: root.selectedTab = "all"
            }
          }
        }

        // ---------- Sub-filter Pills (When in All Tab) ----------
        Row {
          width: parent.width
          visible: root.selectedTab === "all"
          spacing: Style.space(6)

          Repeater {
            model: [
              { id: "today", label: "Today (" + root.todayCount + ")" },
              { id: "tomorrow", label: "Tomorrow" },
              { id: "this_week", label: "This Week" },
              { id: "all", label: "All" }
            ]

            Rectangle {
              width: (parent.width - Style.space(18)) / 4
              height: Style.space(26)
              radius: Style.space(4)
              color: root.dayFilter === modelData.id
                ? Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.18)
                : (filterArea.containsMouse
                    ? Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.08)
                    : "transparent")
              border.width: 1
              border.color: root.dayFilter === modelData.id
                ? Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.3)
                : Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.08)

              Text {
                anchors.centerIn: parent
                text: modelData.label
                color: root.dayFilter === modelData.id ? root.bar.foreground : Qt.darker(root.bar.foreground, 1.3)
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: root.dayFilter === modelData.id
              }

              MouseArea {
                id: filterArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.dayFilter = modelData.id
              }
            }
          }
        }

        PanelSeparator {
          foreground: root.bar.foreground
        }

        // ---------- Scrollable Anime List View ----------
        Item {
          width: parent.width
          height: parent.height - y - Style.space(26)
          clip: true

          // Empty state for Pinned tab
          Column {
            anchors.centerIn: parent
            visible: root.selectedTab === "pinned" && root.getFilteredShows().length === 0
            spacing: Style.space(8)
            width: parent.width * 0.85

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: "⭐"
              font.pixelSize: Style.space(36)
            }

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: "No Pinned Anime Yet"
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.body
              font.bold: true
            }

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              horizontalAlignment: Text.AlignHCenter
              wrapMode: Text.Wrap
              width: parent.width
              text: "Click the star icon ⭐ on any anime in the 'All Shows' tab to track it here!"
              color: Qt.darker(root.bar.foreground, 1.4)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
            }
          }

          ScrollView {
            id: scroll
            anchors.fill: parent
            contentWidth: parent.width
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical.policy: ScrollBar.AsNeeded

            ListView {
              id: list
              width: parent.width
              spacing: Style.space(8)
              model: root.getFilteredShows()

              delegate: Rectangle {
                id: card
                width: list.width
                height: Style.space(66)
                radius: Style.space(6)
                color: cardArea.containsMouse
                  ? Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.15)
                  : Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.05)

                border.width: 1
                border.color: cardArea.containsMouse
                  ? Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.25)
                  : Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.05)

                // Anime Cover Art Image
                Rectangle {
                  id: imgWrap
                  width: Style.space(46)
                  height: Style.space(56)
                  radius: Style.space(4)
                  anchors.left: parent.left
                  anchors.leftMargin: Style.space(6)
                  anchors.verticalCenter: parent.verticalCenter
                  color: Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.1)
                  clip: true

                  Image {
                    anchors.fill: parent
                    source: modelData.coverImage
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                  }
                }

                // Info Column
                Column {
                  anchors.left: imgWrap.right
                  anchors.leftMargin: Style.space(10)
                  anchors.right: pinBtn.left
                  anchors.rightMargin: Style.space(6)
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(3)

                  // Title (Romaji)
                  Text {
                    text: modelData.title
                    color: root.bar.foreground
                    font.family: root.bar.fontFamily
                    font.pixelSize: Style.font.body
                    font.bold: true
                    elide: Text.ElideRight
                    width: parent.width
                  }

                  // Secondary Title / Japanese
                  Text {
                    text: modelData.titleNative ? modelData.titleNative : (modelData.titleEnglish ? modelData.titleEnglish : "")
                    color: Qt.darker(root.bar.foreground, 1.4)
                    font.family: root.bar.fontFamily
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideRight
                    width: parent.width
                    visible: text.length > 0
                  }

                  // Badges Row (Episode + Countdown + Genre)
                  Row {
                    spacing: Style.space(6)

                    // Episode Pill
                    Rectangle {
                      height: Style.space(18)
                      width: epText.implicitWidth + Style.space(10)
                      radius: Style.space(3)
                      color: Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.18)

                      Text {
                        id: epText
                        anchors.centerIn: parent
                        text: "Ep " + modelData.episode + (modelData.totalEpisodes > 0 ? ("/" + modelData.totalEpisodes) : "")
                        color: root.bar.foreground
                        font.family: root.bar.fontFamily
                        font.pixelSize: Style.font.caption
                        font.bold: true
                      }
                    }

                    // Countdown Pill
                    Rectangle {
                      height: Style.space(18)
                      width: countText.implicitWidth + Style.space(10)
                      radius: Style.space(3)
                      color: {
                        var diff = modelData.airingAt - root.currentTimestamp
                        if (diff > 0 && diff <= 3600) return Qt.rgba(0.2, 0.8, 0.4, 0.25)
                        if (diff > 0 && diff <= 86400) return Qt.rgba(0.9, 0.7, 0.2, 0.25)
                        return Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.10)
                      }

                      Text {
                        id: countText
                        anchors.centerIn: parent
                        text: root.formatCountdown(modelData.airingAt)
                        color: {
                          var diff = modelData.airingAt - root.currentTimestamp
                          if (diff > 0 && diff <= 3600) return "#7ce38b"
                          if (diff > 0 && diff <= 86400) return "#f7cf68"
                          return root.bar.foreground
                        }
                        font.family: root.bar.fontFamily
                        font.pixelSize: Style.font.caption
                        font.bold: true
                      }
                    }

                    // Genre Tag
                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      text: (modelData.genres && modelData.genres.length > 0) ? modelData.genres.join(" · ") : ""
                      color: Qt.darker(root.bar.foreground, 1.5)
                      font.family: root.bar.fontFamily
                      font.pixelSize: Style.font.caption
                      elide: Text.ElideRight
                    }
                  }
                }

                // Pin / Star Button
                Rectangle {
                  id: pinBtn
                  anchors.right: parent.right
                  anchors.rightMargin: Style.space(8)
                  anchors.verticalCenter: parent.verticalCenter
                  width: Style.space(32)
                  height: Style.space(32)
                  radius: Style.space(6)
                  color: pinArea.containsMouse
                    ? Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.2)
                    : "transparent"

                  Text {
                    anchors.centerIn: parent
                    text: modelData.pinned ? "⭐" : "☆"
                    color: modelData.pinned ? "#f7cf68" : Qt.darker(root.bar.foreground, 1.4)
                    font.pixelSize: Style.font.body
                  }

                  MouseArea {
                    id: pinArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                      root.triggerAction("pin", modelData.mediaId)
                    }
                  }
                }

                // Click Card Area (opens AniList in browser)
                MouseArea {
                  id: cardArea
                  anchors.fill: parent
                  anchors.rightMargin: Style.space(42) // Leave space for pin button
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    root.triggerAction("open", modelData.siteUrl)
                    root.close()
                  }
                }
              }
            }
          }
        }

        // ---------- Footer Shortcut / Source Hint ----------
        Item {
          width: parent.width
          height: Style.space(16)

          Text {
            anchors.centerIn: parent
            text: "Powered by AniList · Click card to open in browser"
            color: Qt.darker(root.bar.foreground, 1.6)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
          }
        }
      }
    }
  }
}
