;;; -*- Lisp -*- - well, that's stretching a point.  code=data != data=code

;;; first, the headers necessary to find definitions of everything
("usb.h")

;;; then the stuff we're looking for
((:structure device-descriptor 
 	     ("struct usb_device_descriptor"
 	      (integer id-vendor "u_int16_t" "idVendor")
 	      (integer id-product "u_int16_t" "idProduct")))

 (:structure bus 
 	     ("struct usb_bus"
 	      (integer next "struct usb_bus *" "next")
 	      (integer previous "struct usb_bus *" "prev")
 	      (integer devices "struct usb_device *" "devices")))

 ;(:structure device-handle ("struct usb_dev_handle"))

 (:structure device
 	     ("struct usb_device"
 	      (integer next "struct device_bus *" "next")
 	      (integer previous "struct device_bus *" "prev")
 	      (integer bus "struct usb_bus *" "bus")))

 (:function init* ("usb_init" void))
 (:function find-busses* ("usb_find_busses" int))
 (:function find-devices* ("usb_find_devices" int))
 (:function open* ("usb_open" phandle (dev (sb-alien:* device)))) ; 2x pointer
 (:function close* ("usb_close" int (handle phandle))) ; int pointer
 (:function claim-interface* ("usb_claim_interface" int (handle phandle) (interface int)))
 (:function release-interface* ("usb_release_interface" int (handle phandle) (interface int)))
 (:function bulk-read* ("usb_bulk_read" int 
					(handle phandle) 
					(endpoint int)
					(bytes (* sb-alien:char)) 
					(size int)
					(timeout_ms int)))
 (:function bulk-write* ("usb_bulk_write" int 
					  (handle handle)
					  (endpoint int)
					  (bytes (* sb-alien:char))
					  (size int)
					  (timeout_ms int))))

