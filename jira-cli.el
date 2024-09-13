;;;  jira-cli.el --- a simple wrapper around the Jira CLI -*- lexical-binding: t -*-

;;; Commentary:
;;; This package contains some simple functions that wrap around the Jira CLI.
;;; You will need the Jira CLI in order to run them, and it can be installed
;;; from here:
;;;
;;;     https://github.com/ankitpokhrel/jira-cli-cli
;;;
;;; Follow the steps in the README to set-up an API token for the CLI, and
;;; then try running:
;;;
;;;     M-x jira-cli RET.
;;;
;;; In order for web browser previews to work, you must set the
;;; jira-cli-cli-host variable. For example:
;;;
;;;    (setq jira-cli-host "https://my-org.atlassian.net")

;;; Code:
(require 'ansi-color)
(require 'ob-core)

(defgroup jira-cli
  nil
  "Variables for the jira-cli package."
  :group 'applications
  :prefix "jira-cli")

(defcustom jira-cli-host
  nil
  "The URL of your Jira instance, e.g. https://my-org.atlassian.net."
  :type 'string)

(defvar jira-cli--last-reported-flag)
(defvar jira-cli--current-project
  nil
  "The current project used for filtering results.
If nil the default is used from ~/.config/.jira/.config.yml")
(defvar jira-cli--last-exclude-done t)
(defvar jira-cli--current-issue-reference
  nil
  "The issue reference of the currently open issue.")
(defvar jira-cli--current-screen
  "list"
  "The name of the screen-type which is currently being displayed.")

(defun jira-cli--parse-issue-reference (text)
  "Try to parse the Jira issue reference from the provided TEXT."
  (if (string-match "[A-Z]+\\-[0-9]+" text)
      (match-string 0 text)
    nil))

(defun jira-cli--get-current-issue-reference ()
  "Gets the current line's jira issue reference."
  (if (string= jira-cli--current-screen "list")
      (jira-cli--parse-issue-reference
       (buffer-substring-no-properties
	(line-beginning-position)
	(line-end-position)))
    jira-cli--current-issue-reference))

(defun jira-cli--kill-ring-save-reference ()
  "Save the reference of the current issue to the kill ring."
  (interactive)
  (let ((reference (jira-cli--get-current-issue-reference)))
    (message (format "killed reference: %s" reference))
    (kill-new reference)))

(defun jira-cli--view-current-issue ()
  "Views the issue represented by the current line."
  (interactive)
  (jira-cli-view-issue (jira-cli--get-current-issue-reference)))

(defun jira-cli--open-in-browser (reference)
  "Opens the current issue REFERENCE in an external web browser."
  (let ((url (format "%s/browse/%s" jira-cli-host reference)))
    (message (format "opening issue in browser: %s" url))
    (browse-url url)))

(defun jira-cli--view-in-browser ()
  "Opens the current issue in the browser."
  (interactive)
  (jira-cli--open-in-browser (jira-cli--get-current-issue-reference)))

(defun jira-cli ()
  "Lists issues assigned to you."
  (interactive)
  (jira-cli-list-my-assigned-issues))

(defun jira-cli-list-issues-jql (jql)
  "Lists issues found by searching with JQL."
  (interactive "MJQL: ")
  (jira-cli--list-issues nil nil jql))

(defun jira-cli-list-my-assigned-issues ()
  "Lists issues assigned to you."
  (interactive)
  (jira-cli--list-issues "-a" jira-cli--last-exclude-done nil))

(defun jira-cli-list-my-reported-issues ()
  "Lists issues reported by you."
  (interactive)
  (jira-cli--list-issues "-r" jira-cli--last-exclude-done nil))

(defun jira-cli-toggle-exclude-done-issues ()
  "Toggle whether or not to display done issues."
  (interactive)
  (jira-cli--list-issues
   jira-cli--last-reported-flag
   (not  jira-cli--last-exclude-done)
   nil))

(defun jira-cli-set-project (project)
  "Sets the current project to PROJECT."
  (interactive "MProject:")
  (setq jira-cli--current-project project))

(defun jira-cli--set-keys ()
  "Set key bindings for Jira buffers."
  (local-set-key (kbd "q") #'quit-window)
  (local-set-key (kbd "n") #'next-line)
  (local-set-key (kbd "p") #'previous-line)
  (local-set-key (kbd "P") #'jira-cli-set-project)
  (local-set-key (kbd "l") #'jira-cli-list-my-assigned-issues)
  (local-set-key (kbd "j") #'jira-cli-list-issues-jql)
  (local-set-key (kbd "a") #'jira-cli-list-my-assigned-issues)
  (local-set-key (kbd "r") #'jira-cli-list-my-reported-issues)
  (local-set-key (kbd "x") #'jira-cli-toggle-exclude-done-issues)
  (local-set-key (kbd "o") #'jira-cli--view-in-browser)
  (local-set-key (kbd "w") #'jira-cli--kill-ring-save-reference)
  (local-set-key (kbd "e") #'jira-cli-list-epics)
  (local-set-key (kbd "RET") #'jira-cli--view-current-issue))

(defun jira-cli--list-issues (reported-flag exclude-done jql)
  "Lists the issues assigned or reported to you, according to REPORTED-FLAG \\
and EXCLUDE-DONE, or by running the query JQL."
  (setq jira-cli--last-reported-flag reported-flag)
  (setq jira-cli--last-exclude-done exclude-done)
  (setq jira-cli--current-screen "list")
  (let ((buffer (get-buffer-create "jira"))
	(inhibit-read-only t))
    (with-current-buffer buffer
      (erase-buffer)
      (call-process
       "sh"
       nil
       buffer
       nil
       "-c"
       (concat
	"jira issues list"
	(if (not jql) (format " %s $(jira me)" reported-flag) "")
	(if (not jql) (if exclude-done " -s~Done" "") "")
	(if jql (format " --jql '%s'" jql))
	(if jira-cli--current-project
	    (format " --project %s" jira-cli--current-project)
	  "")
	" --plain"
	" --columns 'TYPE,KEY,SUMMARY,STATUS,ASSIGNEE,REPORTER'"))
      (jira-cli--set-keys)
      (read-only-mode t)
      (goto-char (point-min)))
    (display-buffer buffer)))

(defun jira-cli-view-issue (reference)
  "Prints the description of the issue REFERENCE."
  (interactive "sEnter the issue number: ")
  (setq jira-cli--current-screen "view")
  (setq jira-cli--current-issue-reference reference)
  (if (string= reference "")
      (message "No reference provided")
    (let ((buffer (get-buffer-create "jira"))
	  (inhibit-read-only t))
      (with-current-buffer buffer
	(erase-buffer)
	(call-process
	 "sh"
	 nil
	 buffer
	 nil
	 "-c"
	 (format "jira issue view %s | cat" reference))
	(jira-cli--set-keys)
	(ansi-color-apply-on-region (point-min) (point-max))
	(read-only-mode t)
	(goto-char (point-min))
	(display-buffer buffer)))))

(defun jira-cli-list-epics ()
  (interactive)
  (let ((buffer (get-buffer-create "*jira epics*"))
	(inhibit-read-only t))
    (with-current-buffer buffer
      (erase-buffer)
      (call-process
       "sh"
       nil
       buffer
       nil
       "-c"
       "jira epic list --plain --table")
      (jira-cli--set-keys)
      (read-only-mode t)
      (goto-char (point-min)))
    (display-buffer buffer)))

(provide 'jira-cli)
;;; jira-cli.el ends here
