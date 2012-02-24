;;; -*- Lisp -*- - well, that's stretching a point.  code=data != data=code

;;; first, the headers necessary to find definitions of everything
#-win32 ("usb.h")
#+win32 ("C:/Users/martin/Downloads/libusb-win32-bin-1.2.6.0/libusb-win32-bin-1.2.6.0/include/lusb0_usb.h")
;;; then the stuff we're looking for
((:structure device-descriptor 
 	     ("struct usb_device_descriptor"
 	      (unsigned id-vendor "u_int16_t" "idVendor")
 	      (unsigned id-product "u_int16_t" "idProduct")))

 (:structure device
 	     ("struct usb_device"
	      ((sb-alien:* (struct device)) next "struct usb_device *" "next")
	      (device-descriptor descriptor
	       "struct usb_device_descriptor" "descriptor")
	      #+nil ((sb-alien:* (struct bus)) bus "struct usb_bus *" "bus")))

 (:structure bus 
 	     ("struct usb_bus"
 	      ((sb-alien:* (struct bus)) next "struct usb_bus *" "next")
	      ((sb-alien:* (struct device)) devices 
	       "struct usb_device *" "devices")))

 (:function init* ("usb_init" void))
 (:function find-busses* ("usb_find_busses" int))
 (:function find-devices* ("usb_find_devices" int))
 (:function get-busses* ("usb_get_busses" (sb-alien:* bus)))
 (:function open* ("usb_open" phandle 
			      (dev (sb-alien:* device)))) 
 (:function close* ("usb_close" int 
				(handle phandle))) 
 (:function claim-interface* ("usb_claim_interface" int 
						    (handle phandle) 
						    (interface int)))
 (:function release-interface* ("usb_release_interface" int
							(handle phandle) 
							(interface int)))
 (:function bulk-read* ("usb_bulk_read" int 
					(handle phandle) 
					(endpoint int)
					(bytes (* sb-alien:char)) 
					(size int)
					(timeout_ms int)))
 (:function bulk-write* ("usb_bulk_write" int 
					  (handle phandle)
					  (endpoint int)
					  (bytes (* sb-alien:char))
					  (size int)
					  (timeout_ms int))))

