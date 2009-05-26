;;; multi-web-mode.el --- multiple major mode support for web editing

;; Copyright (C) 2009 Fabián Ezequiel Gallina.

;; Author: Fabián Ezequiel Gallina <fgallina@caffeinegroup.com.ar>
;; Maintainer: Fabián Ezequiel Gallina <fgallina@caffeinegroup.com.ar>
;; Keywords: convenience, languages, wp

;; This file is part of Multi Web Mode

;; Multi Web Mode is free software: you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation, either version 3 of the
;; License, or (at your option) any later version.

;; Multi Web Mode is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with Multi Web Mode. If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Multi Web Mode is a minor mode wich makes web editing in Emacs much easier.

;; Basically what it does is select the appropiate major mode
;; automatically when you move the point and also calculates the
;; correct indentation of chunks according to the indentation of the
;; most relevant major mode.

;;

;;; Code:


(defvar mweb-mode-map
  (let ((mweb-mode-map (make-sparse-keymap)))
    (define-key mweb-mode-map [f12] 'mweb-funcall-appropiate-major-mode)
    (define-key mweb-mode-map (kbd "TAB") 'mweb-indent)
    (define-key mweb-mode-map [backtab] 'mweb-indent-line-backward)
    (define-key mweb-mode-map [(meta tab)] 'nxml-complete)
    mweb-mode-map)
  "Keymaps for multi-web-mode")


(defvar mweb-mode-hook nil
  "Hooks to run when multi-web-mode is initialized")

(defvar mweb-extra-indentation 0
  "Extra indentation for chunks, automatically calculated when
  the major mode has changed")

(defcustom mweb-default-major-mode 'nxml-mode
  "Default major mode when editing"
  :type 'symbol
  :group 'multi-web-mode)


(defcustom mweb-filename-extensions
  '("php" "html")
  "Filename extensions on which multi-web-mode should
auto-activate"
  :type '(list string)
  :group 'multi-web-mode)


(defcustom mweb-tags
  '(("<\\?php\\|<\\?" "?>" php-mode)
    ;; "<\\?php"
    ("<script +type=\"text/javascript\"[^>]*>" "</script>" espresso-mode)
    ;; <script type=\"text/javascript\">
    ("<style +type=\"text/css\"[^>]*>" "</style>" css-mode))
    ;; <style +type=\"text/css\"\\( +media=\"screen\"\\)?>
  "Tags enabled for multi-web-mode. This var is an alist on which
each element has the form (\"open tag regex\" \"close tag
regex\" major-mode"
  :type 'alist
  :group 'multi-web-mode)


(defcustom mweb-submodes-magic-indent t
  "*If its value is t then submodes will indent automatically
with their own rules, otherwise it will indent with the offset
defined in `mweb-default-submode-indent-offset'."
  :type 'bool
  :group 'multi-web-mode)


(defcustom mweb-default-submode-indent-offset 4
  "*Indentation offset for submodes when
`mweb-submodes-magic-indent' is t."
  :type 'integer
  :group 'multi-web-mode)


(defcustom mweb-submode-indent-offset 2
  "*Indentation offset for code inside chunks."
  :type 'integer
  :group 'multi-web-mode)


(defun mweb-check-for-html ()
  "Checks if the current buffer contains html tags"
  (interactive)
  (let ((html-tag-re "^\\s-*</?\\sw+.*?>")
        (found nil))
    (save-excursion
      (mweb-goto-current-mode-open-tag)
      (when (re-search-backward "^\\s-*</?\\sw+.*?>" nil t)
        (setq found t)))
    (save-excursion
      (when (mweb-goto-current-mode-close-tag)
        (when (re-search-forward "^\\s-*</?\\sw+.*?>" nil t)
          (setq found t))))
    found))


(defun mweb-funcall-appropiate-major-mode ()
  "Calls the appropiate major mode for the pointed chunk"
  (interactive)
  ;; closes-chunk is a list of the form (point major-mode)
  (let ((closest-chunk-point 0)
        (closest-chunk-mode mweb-default-major-mode)
        (index 0)
        (result nil))
    (while (< index (length mweb-tags))
      (setq result (mweb-find-starting-chunk-point (elt mweb-tags index)))
      (when (integerp result)
        (if (<= closest-chunk-point result)
            (progn
              (setq closest-chunk-point result)
              (setq closest-chunk-mode (elt (elt mweb-tags index) 2)))))
      (setq index (+ index 1)))
    (if (not (equal closest-chunk-mode major-mode))
        (progn
          (funcall closest-chunk-mode)
          t))))


(defun mweb-find-starting-chunk-point (tags)
  "Returns the point of the closest chunk of the element of the
mweb-tags alist passed or nil if the chunk is not found"
  (let ((first-close-point 0)
        (first-open-point 0)
        (open-tag (elt tags 0))
        (close-tag (elt tags 1)))
    ;; check where is the closest open tag or if we are looking at the
    ;; tag itself
    (save-excursion
      (setq first-open-point
            (if (looking-at open-tag)
                (point)
              (re-search-backward open-tag nil t))))
    ;; check where is closest close tag
    (save-excursion
      (setq first-close-point (re-search-backward close-tag nil t)))
    ;; check if we are inside a chunk
    (if (equal first-open-point nil)
        nil
      (progn
        (when (equal first-close-point nil)
          (setq first-close-point 0))
        (if (> first-open-point first-close-point)
            first-open-point
          nil)))))


;; (defun mweb-submode-indent-line ()
;;   "Function to use when indenting a submode line"
;;   (let ((extra-indentation)
;;         (chunk-open-tag-line-pos)
;;         (chunk-close-tag-line-pos)
;;         (subchunk-open-tag-line-pos -1)
;;         (subchunk-close-tag-line-pos -1)
;;         (submajor-mode)
;;         (current-line (line-number-at-pos))
;;         (current-linep (save-excursion
;;                          (beginning-of-line)
;;                          (point-marker)))
;;         (first-nonblank-line))
;;     (save-excursion
;;       (mweb-goto-current-mode-close-tag)
;;       (setq chunk-close-tag-line-pos (line-number-at-pos))
;;       (mweb-goto-current-mode-open-tag)
;;       (setq chunk-open-tag-line-pos (line-number-at-pos))
;;       (when (not (equal chunk-open-tag-line-pos chunk-close-tag-line-pos))
;;         ;; Calculate the relative chunk indentation
;;         (forward-line -1)
;;         (mweb-funcall-appropiate-major-mode)
;;         (setq extra-indentation (mweb-calculate-indentation))
;;         ;; Delete the open tag indentation
;;         (goto-line chunk-open-tag-line-pos)
;;         (delete-horizontal-space)
;;         ;; Get the first nonblank line
;;         (save-excursion
;;           (mweb-forward-nonblank-line 1)
;;           (setq first-nonblank-line (line-number-at-pos)))
;;         ;; Go to the correct first line
;;         (if (< current-line first-nonblank-line)
;;             (goto-line current-line)
;;           (goto-line first-nonblank-line))
;;         ;; call chunk major-mode and indent using the mode's rules
;;         (mweb-funcall-appropiate-major-mode)
;;         (setq submajor-mode major-mode)
;;         (while (<= (line-number-at-pos) current-line)
;;           (when (mweb-looking-at-open-tag)
;;               ;; FIXME esto hace cualquiera
;;             (back-to-indentation)
;;             (mweb-funcall-appropiate-major-mode)

;;             (save-excursion
;;               (mweb-goto-current-mode-close-tag)
;;               (setq subchunk-close-tag-line-pos (line-number-at-pos)))
;;             (save-excursion
;;               (mweb-goto-current-mode-open-tag)
;;               (setq subchunk-open-tag-line-pos (line-number-at-pos)))
;;             (delete-horizontal-space)
;;             (if (not (equal subchunk-open-tag-line-pos subchunk-close-tag-line-pos))
;;                 (progn
;;                   (while (< (line-number-at-pos) subchunk-close-tag-line-pos)
;;                     (forward-line 1)
;;                     (delete-horizontal-space)
;;                     (indent-to mweb-submode-indent-offset))
;;                   (delete-horizontal-space))
;;               (forward-line 1)))
;;           (indent-according-to-mode)
;;           (forward-line 1))
;;         (forward-line -1)
;;         ;; Go to the correct first line
;;         (goto-line chunk-open-tag-line-pos)
;;         (if (< current-line first-nonblank-line)
;;             (goto-line current-line)
;;           (goto-line first-nonblank-line))
;;         ;; add the additional indentation to all the chunk's lines
;;         (while (<= (line-number-at-pos) current-line)
;;           (indent-to (+ extra-indentation mweb-submode-indent-offset))
;;           (forward-line 1))
;;         (forward-line -1)
;;         ;; fix the open tag and close tag indentation
;;         (goto-line chunk-open-tag-line-pos)
;;         (indent-to extra-indentation)
;;         (goto-line chunk-close-tag-line-pos)
;;         (delete-horizontal-space)
;;         (indent-to extra-indentation)))))


(defun mweb-update-extra-indentation ()
  "The function which is appended to the `post-command-hook'"
  (when (and (mweb-funcall-appropiate-major-mode)
             (not (equal major-mode mweb-default-major-mode)))
    (save-excursion
      (mweb-goto-current-mode-open-tag)
      (forward-line -1)
      (mweb-funcall-appropiate-major-mode)
      (setq mweb-extra-indentation (mweb-calculate-indentation)))
    (mweb-funcall-appropiate-major-mode))
  (when (equal major-mode mweb-default-major-mode)
    (setq mweb-extra-indentation 0)))


(defun mweb-submode-indent-line ()
  "Function to use when indenting a submode line"
  (interactive)
  (mweb-funcall-appropiate-major-mode)
  (if (not (mweb-looking-at-open-tag))
      (if (not (mweb-looking-at-close-tag))
          (save-excursion
            (beginning-of-line)
            (delete-horizontal-space)
            (indent-according-to-mode)
            (indent-to (+ mweb-extra-indentation mweb-submode-indent-offset)))
        (let ((open-tag-indentation 0))
          (save-excursion
            (mweb-goto-current-mode-open-tag)
            (setq open-tag-indentation (current-indentation)))
          (beginning-of-line)
          (delete-horizontal-space)
          (indent-to open-tag-indentation)))
    (progn
      (beginning-of-line)
      (delete-horizontal-space)
      (insert "a")
      (delete-horizontal-space)
      (beginning-of-line)
      (mweb-update-extra-indentation)
      (indent-according-to-mode)
      (indent-to (+ mweb-extra-indentation mweb-submode-indent-offset))
      (delete-char 1))))


(defun mweb-indent-line-forward ()
  "Indents the line according to the mode and in relation with
the default major mode.

In the case that the default major mode is beign used then it
will fallback to the `indent-according-to-mode-command' function
but if the current line's mode is not the default major mode then
it will indent the line taking into account the relative position
of the chunk in regards to the default major mode.

It is important to note that on a chunk which does not
corresponds to the default major mode (ie: a php chunk) it will
indent all the previous line of the chunk as well. This is done
because this way the relative position is calculated more
acurately."
  (interactive "*")
    (if (not (equal major-mode mweb-default-major-mode))
        (when mweb-submodes-magic-indent
          (if (mweb-check-for-html)
              (mweb-submode-indent-line)
            (indent-according-to-mode)))
      (indent-according-to-mode))
    (when (equal (mweb-get-current-line-contents) "")
      (back-to-indentation)))


(defun mweb-indent-line-backward ()
  "Deletes indentation, useful when magic
indentation `mweb-submodes-magic-indent' is nil.

It deletes the number of spaces defined in
`mweb-default-submode-indent-offset'"
  (interactive "*")
  (when (not mweb-submodes-magic-indent)
    (if (not (equal major-mode mweb-default-major-mode))
        (let ((ci (current-indentation)))
          (save-excursion
            (beginning-of-line)
            (delete-horizontal-space)
            (indent-to (- ci mweb-default-submode-indent-offset))))
      (indent-according-to-mode))))


(defun mweb-indent-region (start end)
  "Indents a region taking into account the relative position of
the chunks within the buffer.

It follows the same filosophy than `mweb-indent-line-forward'
because that function is what is used to indent the chunks
which are not for the default major mode."
  (interactive "r")
  (let ((line-end))
    (save-excursion
      (goto-char end)
      (setq line-end (line-number-at-pos)))
    (save-excursion
      (goto-char start)
      (beginning-of-line)
      (mweb-update-extra-indentation)
      (while (< (line-number-at-pos) line-end)
        (mweb-update-extra-indentation)
        (mweb-indent-line-forward)
        (forward-line 1)))))


(defun mweb-calculate-indentation ()
  "Helper used to calculate the correct indentation taking into
account the previous submode"
  (interactive)
  (let ((indentation 0)
        (eol))
    (save-excursion
      (mweb-funcall-appropiate-major-mode)
      (end-of-line)
      (insert "\n")
      (insert "a")
      (if (equal major-mode mweb-default-major-mode)
          (indent-according-to-mode)
        (mweb-submode-indent-line))
      (setq indentation (current-indentation))
      (end-of-line)
      (setq eol (point-marker))
      (beginning-of-line)
      (delete-region (point-marker) eol)
      (delete-backward-char 1))
    (mweb-funcall-appropiate-major-mode)
    indentation))


(defun mweb-indent (&optional arg)
  "If a region is selected then calls `mweb-indent-region' else
calls `mweb-indent-line-forward`"
  (interactive "P")
  (if (use-region-p)
      (mweb-indent-region (region-beginning) (region-end))
    (mweb-indent-line-forward)))


(defun mweb-get-current-mode-open-tag ()
  "Moves the cursor to the open tag of the current chunk"
  (interactive)
  (let ((index 0)
        (found nil)
        (tag)
        (result nil))
    (while (and (< index (length mweb-tags))
                (not found))
      (setq tag (elt mweb-tags index))
      (when (or (equal (elt tag 2) major-mode)
                (equal major-mode mweb-default-major-mode))
        (setq found t)
        (save-excursion
          (if (looking-at (elt tag 0))
              (progn
                (back-to-indentation)
                (setq result (point-marker)))
            (setq result (re-search-backward (elt tag 0) nil t)))))
      (setq index (+ 1 index)))
    result))


(defun mweb-get-current-mode-close-tag ()
  "Moves the cursor to the close tag of the current chunk"
  (interactive)
  (let ((index 0)
        (found nil)
        (tag)
        (result nil))
    (while (and (< index (length mweb-tags))
                (not found))
      (setq tag (elt mweb-tags index))
      (when (or (equal (elt tag 2) major-mode)
                (equal major-mode mweb-default-major-mode))
        (setq found t)
        (save-excursion
          (setq result (re-search-forward (elt tag 1) nil t))))
      (setq index (+ 1 index)))
    result))


(defun mweb-goto-current-mode-close-tag ()
  (interactive)
  (let ((tag-point (mweb-get-current-mode-close-tag)))
    (when tag-point
      (goto-char tag-point))))


(defun mweb-goto-current-mode-open-tag ()
  (interactive)
  (let ((tag-point (mweb-get-current-mode-open-tag)))
    (when tag-point
      (goto-char tag-point))))


(defun mweb-forward-nonblank-line (&optional number)
  "Moves the cursor to the next/previous non blank line.

With a positive argument it searches forward and with a negative
it searches backwards."
  (when (not number)
    (setq number 1))
  (when (> number 1)
    (setq number 1))
  (when (< number -1)
    (setq number -1))
  (forward-line number)
  (while (and (equal (mweb-get-current-line-contents) "")
              (not (eobp)))
    (forward-line number)))


(defun mweb-get-current-line-contents ()
  "Gets the contents of the current line without space chars"
  (let ((start-point)
        (end-point)
        (contents))
    (save-excursion
      (beginning-of-line)
      (setq start-point (point))
      (end-of-line)
      (setq end-point (point))
      (setq contents (buffer-substring start-point end-point))
      (when (string-match "[ \t]*$" contents)
        (setq contents (replace-match "" nil nil contents)))
      (when (string-match "^[ \t]*" contents)
        (setq contents (replace-match "" nil nil contents))))
    contents))


(defun mweb-looking-at-tag ()
  "returns t if pointer is looking at an open or close tag"
  (let ((index 0)
        (looking nil)
        (open-tag)
        (close-tag)
        (result nil))
    (save-excursion
      (back-to-indentation)
      (while (and (< index (length mweb-tags))
                  (not looking))
        (setq open-tag (elt (elt mweb-tags index) 0))
        (setq close-tag (elt (elt mweb-tags index) 1))
        (when (or (looking-at open-tag)
                  (looking-at close-tag))
          (setq looking t))
        (setq index (+ 1 index))))
    looking))


(defun mweb-looking-at-open-tag ()
  "returns t if pointer is looking at an open tag"
  (let ((index 0)
        (looking nil)
        (open-tag)
        (result nil))
    (save-excursion
      (back-to-indentation)
      (mweb-funcall-appropiate-major-mode)
      (while (and (< index (length mweb-tags))
                  (not looking))
        (setq open-tag (elt (elt mweb-tags index) 0))
        (when (looking-at open-tag)
          (setq looking t))
        (setq index (+ 1 index))))
    looking))


(defun mweb-looking-at-close-tag ()
  "returns t if pointer is looking at a close tag"
  (let ((index 0)
        (looking nil)
        (close-tag)
        (result nil))
    (save-excursion
      (back-to-indentation)
      (mweb-funcall-appropiate-major-mode)
      (while (and (< index (length mweb-tags))
                  (not looking))
        (setq close-tag (elt (elt mweb-tags index) 1))
        (when (looking-at close-tag)
          (setq looking t))
        (setq index (+ 1 index))))
    looking))


(defun mweb-post-command-hook ()
  "The function which is appended to the `post-command-hook'"
  (if multi-web-mode
      (when (not (region-active-p))
        (when (and (mweb-funcall-appropiate-major-mode)
                   (not (equal major-mode mweb-default-major-mode)))
          (save-excursion
            (mweb-goto-current-mode-open-tag)
            (forward-line -1)
            (setq mweb-extra-indentation (mweb-calculate-indentation)))
          (mweb-funcall-appropiate-major-mode)))))


(defun mweb-post-command-hook ()
  "The function which is appended to the `post-command-hook'"
  (when (and multi-web-mode
             (not (region-active-p)))
    (mweb-update-extra-indentation)))

(defun mweb-check-current-mode ()
  "Checks if the current major mode is in the `mweb-tags' alist"
  (interactive)
  (let ((index 0)
        (found nil)
        (tag))
    (while (and (< index (length mweb-tags))
                (not found))
      (setq tag (elt mweb-tags index))
      (when (or (equal (elt tag 2) major-mode)
                (equal major-mode mweb-default-major-mode))
        (setq found t))
      (setq index (+ 1 index)))
    found))


(defun mweb-check-filename-extensions ()
  "Checks if the current buffer extension is in the
`mweb-filename-extensions' list"
  (interactive)
  (let ((index 0)
        (result nil)
        (found nil))
    (when buffer-file-name
      (while (and (< index (length mweb-filename-extensions))
                  (not found))
        (when (equal (file-name-extension buffer-file-name) (elt mweb-filename-extensions index))
          (setq found t))
        (setq index (1+ index))))
    found))


(defun mweb-enable ()
  "This function initializes the minor mode"
  (add-hook 'post-command-hook 'mweb-post-command-hook)
  (use-local-map mweb-mode-map)
  (run-hooks 'mweb-mode-hook))


(defun mweb-disable ()
  "This function takes care to disable the minor mode"
  ;; (remove-hook 'post-command-hook 'mweb-post-command-hook))
)


;;;###autoload
(define-minor-mode multi-web-mode
  "Enables the multi web mode chunk detection and indentation"
  :lighter " Multi-Web" :group 'convenience
  (if multi-web-mode
      (mweb-enable)
    (mweb-disable)))


;; Check if multi-web-mode should be activated for the file
(add-hook 'find-file-hook
          (lambda ()
            (if (mweb-check-filename-extensions)
                (progn
                  (multi-web-mode 1))
              (progn
                (multi-web-mode -1)))))


;; Check if multi-web-mode should be activated for the mode
(add-hook 'after-change-major-mode-hook
          (lambda ()
            (if (mweb-check-filename-extensions)
                (progn
                  (multi-web-mode 1))
              (progn
                (multi-web-mode -1)))))


(provide 'multi-web-mode)

;;; multi-web-mode-el ends here