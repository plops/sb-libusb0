(defpackage :sb-libusb0-internal
  (:nicknames :usbint)
  (:use :cl :sb-alien)
  (:export
   :with-usb-open
   :with-claimed-interface
   :ensure-libusb0-initialized
   :get-devices-by-ids
   :with-ep
   :bulk-write
   :bulk-read))

(defpackage :sb-libusb0
  (:export)
  (:use :cl :sb-libusb0-internal))