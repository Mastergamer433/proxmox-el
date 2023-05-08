;;; proxmox.el --- Proxmox api implementation -*- lexical-binding: t -*-

;; Copyright (C) 2023 Elis Odenhage

;; Author: Elis Odenhage <mg433@kimane.se>
;; Version: 0.0.1
;; Package-Requires: ((request "0.3.3") (s "1.13.1") (jeison "1.0.0"))
;; Keywords: vm, proxmox
;; URL: https://github.com/mastergamer433/proxmox-el

;; This file is NOT part of GNU Emacs.

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; This package provides some command to make requests to the proxmox api

;;;###autoload
(defun proxmox-clone-vm ()
  "Clone a proxmox vm."
  (interactive)
  (let* ((vmid (jeison-read t (proxmox-select-a-vm) "vmid")))
    (request (format "%s/nodes/pve/qemu/%s/clone" proxmox-base-url vmid)
      :type "POST"
      :headers `(("Authorization" . ,(format "PVEAPIToken=%s" (password-store-get "proxmox/api"))))
      :params `(("full" . "1") ("newid" . ,(completing-read "New vm's id: " ())) ("name" . ,(completing-read "New vm's name: " ())))
      :success (cl-function
                (lambda (&key data &allow-other-keys)
                  (message "I sent: %S" (assoc-default 'form data)))))
    vmid))

(defun proxmox-power-off-vm (&optional vmid)
  "Shutdown the proxmox vm with the vmid VMID."
  (interactive)
  (let* ((vmid (if vmid vmid (jeison-read t (proxmox-select-a-vm) "vmid"))))
    (request (format "%s/nodes/pve/qemu/%s/status/stop" proxmox-base-url vmid)
      :type "POST"
      :headers `(("Authorization" . ,(format "PVEAPIToken=%s" (password-store-get "proxmox/api"))))
      :success (cl-function
                (lambda (&key data &allow-other-keys)
                  (message "I sent: %S" (assoc-default 'form data)))))))

(defun proxmox-power-on-vm (&optional vmid)
  "Turn on the proxmox vm with the vmid VMID."
  (interactive)
  (let* ((vmid (if vmid vmid (jeison-read t (proxmox-select-a-vm) "vmid"))))
    (request (format "%s/nodes/pve/qemu/%s/status/start" proxmox-base-url vmid)
      :type "POST"
      :headers `(("Authorization" . ,(format "PVEAPIToken=%s" (password-store-get "proxmox/api"))))
      :success (cl-function
                (lambda (&key data &allow-other-keys)
                  (message "I sent: %S" (assoc-default 'form data)))))))

(defun proxmox-restart-vm (&optional vmid)
  "Restart the proxmox vm with the vmid VMID."
  (interactive)
  (let* ((vmid (if vmid vmid (jeison-read t (proxmox-select-a-vm) "vmid"))))
    (request (format "%s/nodes/pve/qemu/%s/status/reboot" proxmox-base-url vmid)
      :type "POST"
      :headers `(("Authorization" . ,(format "PVEAPIToken=%s" (password-store-get "proxmox/api"))))
      :success (cl-function
                (lambda (&key data &allow-other-keys)
                  (message "I sent: %S" (assoc-default 'form data)))))))

;;; Code:

(defcustom proxmox-base-url "https://proxmox.kimane.se/api2/json")

(defun proxmox-get-vms ()
  (defvar vms)
  (request (format "%s/nodes/pve/qemu" proxmox-base-url)
    :headers `(("Authorization" . ,(format "PVEAPIToken=%s" (password-store-get "proxmox/api"))))
    :parser (lambda () (buffer-string))
    :success (cl-function
              (lambda (&key data &allow-other-keys)
                (setq vms data))))
  vms)

(defun proxmox-get-vm-by-name (name)
  (let* ((vms (jeison-read t (proxmox-get-vms) "data"))
         (VM (list)))
    (mapcar
     (lambda (vm)
       (if (equal name (jeison-read t vm "name"))
           (setq VM vm)))
     vms)
    VM))

(defun proxmox-get-vm-by-name (vmid)
  (let* ((vms (jeison-read t (proxmox-get-vms) "data"))
         (VM (list)))
    (mapcar
     (lambda (vm)
       (if (equal vmid (jeison-read t vm "vmid"))
           (setq VM vm)))
     vms)
    VM))

(defun proxmox-get-vm-names ()
  (let* ((vms (jeison-read t (proxmox-get-vms) "data")))
    (mapcar
     (lambda (vm)
       (jeison-read t vm "name"))
     vms)))

(defun proxmox-select-a-vm ()
  (proxmox-get-vm-by-name (completing-read "VM: " (proxmox-get-vm-names))))


(defun proxmox-get-ip (vmid)
  (defvar ifs
    "Interfaces")
  (defvar IF
    "Interface.")
  (defvar IP
    "Ip address of interface".)
  (request (format "%s/nodes/pve/qemu/%s/agent/network-get-interfaces" proxmox-base-url vmid)
    :headers `(("Authorization" . ,(format "PVEAPIToken=%s" (password-store-get "proxmox/api"))))
    :parser (lambda () (buffer-string))
    :success (cl-function
              (lambda (&key data &allow-other-keys)
                (setq ifs data))))
  (mapcar
   (lambda (if)
     (if (equal "eth0" (jeison-read t if "name"))
         (setq IF if)))
   (jeison-read t (jeison-read t ifs "data") "result"))

  (mapcar
   (lambda (ip)
     (if (equal "ipv4" (jeison-read t ip "ip-address-type"))
         (setq IP (jeison-read t ip "ip-address"))))
   (jeison-read t IF "ip-addresses"))
  IP)

(provide 'proxmox)

;;; proxmox.el ends here
