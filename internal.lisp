(in-package :sb-libusb0-internal)

(sb-alien:define-alien-type handle int)
(sb-alien:define-alien-type phandle (sb-alien:* handle))

(defvar *libusb0-initialized* nil)
(defvar *libusb0-shared-object* nil)

(defmacro check (&body body)
  `(let ((val (progn ,@body)))
     (if (< val 0)
	 (error (format nil "libusb error: ~a returned ~a" ',@body val))
	 val)))

(defun ensure-libusb0-initialized ()
  (unless *libusb0-initialized*
    (setf *libusb0-shared-object* (sb-alien:load-shared-object "libusb.so"))
    (init*)
    (setf *libusb0-initialized* t))
  (list (check (find-busses*))
	(check (find-devices*))))


(defun get-busses ()
  (ensure-libusb0-initialized)
  (loop with bus = (get-busses*)
     until (sb-alien:null-alien bus)
     collect bus
     do (setf bus (bus-next bus))))
#+nil
(format t "~a~%" (bus-next (get-busses*)))


;; #+nil
;; (check (cl-usb::usb-find-devices))

;; #+nil
;; (defparameter *b2* (car (get-busses)))

;; #+nil
;; (cffi:foreign-slot-value (car (get-busses))
;; 			 'cl-usb::usb_bus
;; 			 'cl-usb::devices)


(defun get-devices* (bus)
  (ensure-libusb0-initialized)
  (loop with dev = (bus-devices bus)
       until (sb-alien:null-alien dev)
       collect dev
       do (setf dev (device-next dev))))

(defun get-devices (&optional (bus-or-list (get-busses)))
  (if (listp bus-or-list)
      (loop for bus in bus-or-list
	   nconcing (get-devices* bus))
      (get-devices* bus-or-list)))

;; #+nil
;; (get-devices (car (cdr (get-busses))))

;; #+nil
;; (get-devices* 
;;  (car (cdr (get-busses))))

(defun get-vendor-id (dev)
  (sb-alien:slot 
   (device-descriptor dev)
   'id-vendor))

(defun get-product-id (dev)
  (sb-alien:slot
   (device-descriptor dev)
   'id-product))

#+nil
(mapcar #'(lambda (e) (format nil "#x~X" (get-product-id e))) (get-devices))

(defun get-devices-by-ids (&key (vendor-id nil) (product-id nil))
  (flet ((ids-match (dev)
	   (and (or (null vendor-id)
		    (= vendor-id (get-vendor-id dev)))
		(or (null product-id)
		    (= product-id (get-product-id dev))))))
    (delete-if-not #'ids-match (get-devices))))



(defparameter *current-device* 0)
(defparameter *current-handle* 0)
(defparameter *current-ep* 0)
(defparameter *current-interface* 0)

(defun usb-open (&optional (dev *current-device*))
  "Returns handle"
  (open* dev))

(defun usb-close (&optional (handle *current-handle*))
  (check
   (close* handle)))

(defmacro with-usb-open (dev &body body)
  `(let ((*current-device* ,dev))
     (let ((*current-handle* (usb-open ,dev)))
       ,@body
       (usb-close))))

(defun claim-interface (&key (handle *current-handle*)
			(interface *current-interface*))
  (declare (type fixnum interface))
  (check
    (claim-interface* handle interface)))

(defun release-interface (&key (handle *current-handle*) (interface *current-interface*))
  (declare (type fixnum interface))
  (check
   (release-interface* handle interface)))

(defmacro with-claimed-interface ((interface &key (handle *current-handle*))
				  &body body)
  `(let ((*current-interface* ,interface))
     (claim-interface :handle ,handle :interface ,interface)
     ,@body
     (release-interface :handle ,handle :interface ,interface)
     (values)))

(defmacro with-ep (ep &body body)
  `(let ((*current-ep* ,ep))
     ,@body))

(defun bulk-write (data &key (handle *current-handle*) (ep *current-ep*)
		   (timeout_ms 1000))
  (declare (type (simple-array (unsigned-byte 8) 1) data))
  (let ((len (sb-sys:with-pinned-objects (data)
	       (check 
		 (bulk-write* handle 
			      ep 
			      (sb-sys:vector-sap data)
			      (length data) 
			      timeout_ms)))))
    (unless (= len (length data))
      (error "libusb: couldn't write all data."))
    len))

(defun bulk-read (bytes-to-read &key (handle *current-handle*) (ep *current-ep*)
		  (timeout_ms 1000))
  ;; interface must be claimed
  (let ((data (make-array bytes-to-read :element-type '(unsigned-byte 8))))
    (declare (type (simple-array (unsigned-byte 8) 1) data))
    (let ((len (sb-sys:with-pinned-objects (data)
		 (check
		   (bulk-read* handle
			       ep
			       (sb-sys:vector-sap data)
			       bytes-to-read
			       timeout_ms)))))
      (if (= len bytes-to-read)
	  data
	  (progn
	    (format t "libusb: couldn't read all data.")
	    (subseq data 0 len))))))
