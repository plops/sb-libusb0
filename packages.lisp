(defpackage :sb-libusb0-internal
  (:nicknames :usbint)
  (:use :cl :sb-alien))

(defpackage :sb-libusb0
  (:export)
  (:use :cl :sb-libusb0-internal))