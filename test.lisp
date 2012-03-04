#+nil
(eval-when (:compile-toplevel :execute :load-toplevel)
 ;(push "/home/martin/0220/sb-libusb0/" asdf:*central-registry*)
 (setf asdf:*central-registry* 
       '("c:/Users/martin/Desktop/tmp/0220/sb-libusb0/") ))
(require :sb-libusb0)

#+nil
(sb-libusb0-internal::ensure-libusb0-initialized)

#+nil
(usbint::get-busses)

#+nil
(usbint::get-devices)

#+nil
(sb-libusb0-internal::bus-next (sb-libusb0-internal::get-busses*))

#+nil
(sb-libusb0-internal::bus-devices
 (sb-libusb0-internal::bus-next (sb-libusb0-internal::get-busses*)))

#+nil
(sb-libusb0-internal::device-next
 (sb-libusb0-internal::bus-devices
  (sb-libusb0-internal::get-busses*)))

#+nil
(sb-alien:addr (sb-libusb0-internal::get-devices))

#+nil
(defparameter *d*
  (car
   (sb-libusb0-internal::get-devices-by-ids :vendor-id #x058f :product-id #xb002)))

#+nil
(defparameter *d2*
 (sb-libusb0-internal::usb-open *d*))

#+nil
(usbint::check
 (usbint::claim-interface* *d2* 1))