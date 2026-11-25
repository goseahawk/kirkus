// kirkus: the desktop a new account starts with. KDE's standard panel (its own template, so it
// stays current with Plasma), with the kirkus bird on the Application Launcher button.
loadTemplate("org.kde.plasma.desktop.defaultPanel")

panels().forEach(function (panel) {
    panel.widgets("org.kde.plasma.kickoff").forEach(function (launcher) {
        launcher.currentConfigGroup = ["General"];
        launcher.writeConfig("icon", "kirkus-mark");
    });
});

var desktopsArray = desktopsForActivity(currentActivity());
for (var j = 0; j < desktopsArray.length; j++) {
    desktopsArray[j].wallpaperPlugin = 'org.kde.image';
}
