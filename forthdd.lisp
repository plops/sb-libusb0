(require :sb-libusb0)

(defpackage :forthdd
  (:use :cl :sb-libusb0-internal))

(in-package :forthdd)

(with-usb-open (car (get-devices-by-ids :vendor-id #x19ec :product-id #x0300))
  (with-ep #x04
    ))