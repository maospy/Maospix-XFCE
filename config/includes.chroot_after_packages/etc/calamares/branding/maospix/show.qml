/* Diapositivas de maospix mientras se instala (imágenes de assets/gen-calamares.py) */
import QtQuick 2.0;
import calamares.slideshow 1.0;

Presentation
{
    id: presentation

    Timer {
        interval: 15000
        running: presentation.activatedInCalamares
        repeat: true
        onTriggered: presentation.goToNextSlide()
    }

    Rectangle { anchors.fill: parent; color: "#0f1524"; z: -1 }

    Slide { Image { source: "slide1.png"; anchors.fill: parent; fillMode: Image.PreserveAspectFit } }
    Slide { Image { source: "slide2.png"; anchors.fill: parent; fillMode: Image.PreserveAspectFit } }
    Slide { Image { source: "slide3.png"; anchors.fill: parent; fillMode: Image.PreserveAspectFit } }

    function onActivate() { }
    function onLeave() { }
}
