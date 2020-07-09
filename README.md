# xfs-undelete
XFS file system undelete function.

;; Restoring XFS 3 (Version 5) only ! Others may work (or not).

;; Motivation:
;; Some hundreds of GB of deleted data needed to be restored as much as poss.
;; Available tools crashed or created anonymous files.
;; Since we had hundred thousands of files to recover, restoring
;; the directory structure plus files inside was mandatory.
;; Instead of looping over lost inodes this prog attempts to
;; decend from the root inode of the XFS partition into the leaves and
;; recreate the DIR structure as much as poss.

;; Usage/Usability:
;; WARNING: This is by no means a complete bulletproofed solution !
;; It did the job for us though.
;; You MAY need to ADOPT some things for YOUR XFS system.

;; Pls check the comments in the source for further informations.

;; Readings (Highly recommended) :
;; XFS Filesystem Disk Structures 3rd Edition
;; Copyright © 2006 Silicon Graphics Inc.
;; and
;; https://xfs.org/index.php/XFS_FAQ
