;;; ddragon.el --- Browse Data Dragon                -*- lexical-binding: t; -*-

;; Copyright (C) 2019  Xu Chunyang

;; Author: Xu Chunyang
;; Homepage: https://github.com/xuchunyang/ddragon.el
;; Package-Requires: ((emacs "25.1"))
;; Version: 0

;; This program is free software; you can redistribute it and/or modify
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

;; Browse Champions of League of Legends

;; [[https://developer.riotgames.com/ddragon.html][Riot Developer Portal]]

;;; Code:

(require 'seq)
(require 'json)
(eval-when-compile
  ;; For `string-join' which is an inline function
  (require 'subr-x))

(defgroup ddragon nil
  "Browse Data Dragon."
  :group 'applications)

(defun ddragon-versions ()
  "Return a list of ddragon versions (strings), the first is the latest."
  (with-current-buffer (url-retrieve-synchronously
                        "https://ddragon.leagueoflegends.com/api/versions.json")
    ;; `url-http-end-of-headers' seems to be 1 after cache is used
    ;; (goto-char url-http-end-of-headers)
    (goto-char (point-min))
    (re-search-forward "^\r?\n")
    (let ((json-array-type 'list))
      (json-read))))

(defun ddragon-url ()
  "Return url to the latest version of data dragon.
Such as the URL `https://ddragon.leagueoflegends.com/cdn/dragontail-9.15.1.tgz'."
  (format "https://ddragon.leagueoflegends.com/cdn/dragontail-%s.tgz"
          (car (ddragon-versions))))

(defcustom ddragon-dir
  (pcase (expand-file-name
          "dragontail-9.15.1/"
          (file-name-directory
           (or load-file-name buffer-file-name)))
    ((and (pred file-exists-p) dir) dir))
  "Directory to dragontail.
Such as '~/src/ddragon.el/dragontail-9.15.1/'."
  :type '(choice (const :tag "Not set" nil)
                 (string :tag "Directory to dragontail."))
  :group 'ddragon)

(defun ddragon-dir-main ()
  "Main directory in `ddragon-dir', such as '9.15.1'."
  (seq-find
   (lambda (x)
     (and (file-directory-p x)
          (string-match-p
           (rx (1+ (and (1+ num) ".")) (1+ num))
           (file-name-nondirectory x))))
   (directory-files ddragon-dir t)))

(defvar image-dired-show-all-from-dir-max-files)

;;;###autoload
(defun ddragon-champion-image-dired ()
  "Show all champions using `image-dired'."
  (interactive)
  ;; There are 145 champions in League of Legends as of Aug 7, 2019
  (let ((image-dired-show-all-from-dir-max-files 200))
    (image-dired (expand-file-name "img/champion" (ddragon-dir-main)))))

(defun ddragon-languages ()
  "Return a list of languages."
  (let ((json-array-type 'list))
    (json-read-file (expand-file-name "languages.json" ddragon-dir))))

(defun ddragon-champions ()
  "Return a list of champions IDs."
  (mapcar
   #'symbol-name
   (mapcar
    #'car
    (alist-get
     'data
     (json-read-file
      (expand-file-name
       ;; any language should work
       "data/en_US/champion.json"
       (ddragon-dir-main)))))))

(defun ddragon--fill-string (string)
  "Fill STRING."
  (with-temp-buffer
    (insert string)
    (fill-region (point-min) (point-max))
    (buffer-string)))

;;;###autoload
(defun ddragon-champion-show-plain (id lang)
  "Show infomation of a champion by ID in LANG with plain text.
Such as, \"Teemo\" and \"zh_CN\"."
  (interactive (list (completing-read "Champion: " (ddragon-champions))
                     (completing-read "Language: " (ddragon-languages))))
  (let* ((json-file (expand-file-name (format "data/%s/champion/%s.json" lang id)
                                      (ddragon-dir-main)))
         (json-data (let ((json-object-type 'alist)
                          (json-array-type  'list)
                          (json-key-type    'symbol)
                          (json-false       nil)
                          (json-null        nil))
                      (json-read-file json-file)))
         (main-data (alist-get (intern id) (alist-get 'data json-data))))
    (with-current-buffer (get-buffer-create (format "*%s*" id))
      (read-only-mode)
      (let ((inhibit-read-only t))
        (erase-buffer)
        (let-alist main-data
          (insert
           (string-join
            `(,(concat .name " " .title)
              ,(format "(P) %s\n\n%s"
                       .passive.name
                       (ddragon--fill-string
                        .passive.description))
              ,@(seq-mapn (lambda (key spell)
                            (let-alist spell
                              (format "(%c) %s\n\n%s"
                                      key
                                      .name
                                      (ddragon--fill-string .description))))
                          "QWER"
                          .spells))
            "\n\n")))
        (goto-char (point-min)))
      (display-buffer (current-buffer)))))

(provide 'ddragon)
;;; ddragon.el ends here