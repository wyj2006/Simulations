import struct
import sys

import matplotlib.pyplot as plt
from matplotlib.backends.backend_qtagg import FigureCanvasQTAgg as FigureCanvas
from PyQt6.QtCore import QTimer, pyqtSlot
from PyQt6.QtWidgets import QApplication, QWidget

from ui_render import Ui_Render


class Render(QWidget, Ui_Render):
    def __init__(self):
        super().__init__()
        self.setupUi(self)

        self.data = open(".dat", mode="rb").read()
        self.sand_num, *_ = struct.unpack("Q", self.data[0:8])
        self.frame = []
        for i in range(8, len(self.data), self.sand_num * 3 * 8):
            self.frame.append(
                [
                    list(struct.unpack("ddd", self.data[j : j + 3 * 8]))
                    for j in range(i, i + self.sand_num * 3 * 8, 3 * 8)
                ]
            )

        self.figure = plt.figure()
        self.axes = self.figure.add_subplot(projection="3d")
        self.canvas = FigureCanvas(self.figure)
        self.canvas_layout.addWidget(self.canvas)

        self.frame_slider.setMaximum(len(self.frame) - 1)
        self.frame_slider.setValue(0)

        self.timer = QTimer(self)
        self.timer.timeout.connect(
            lambda: self.frame_slider.setValue(
                (self.frame_slider.value() + 1) % self.frame_slider.maximum()
            )
        )
        self.timer.setInterval(10)

    @pyqtSlot(int)
    def on_frame_slider_valueChanged(self, index):
        self.frame_label.setText(f"Frame: {index}")
        self.axes.clear()
        xs, ys, zs = [], [], []
        for i in self.frame[index]:
            if i[2] < -1:
                continue
            xs.append(i[0])
            ys.append(i[1])
            zs.append(i[2])
        self.axes.scatter(xs, ys, zs)
        self.canvas.draw()

    @pyqtSlot(bool)
    def on_start_button_clicked(self, _):
        self.timer.start()

    @pyqtSlot(bool)
    def on_stop_button_clicked(self, _):
        self.timer.stop()


if __name__ == "__main__":
    app = QApplication(sys.argv)
    render = Render()
    render.show()
    sys.exit(app.exec())
