(add-to-list 'load-path "./")
(require 'jira-cli)
(require 'ert)
(require 'f)

(defun make-jira-cli ()
  (let ((name (make-temp-file "jira")))
    (f-write-text "#!/bin/bash
if [[ \"$1\" == \"issue\" && \"$2\" == \"list\" ]]; then
cat <<EOF
TYPE	KEY		SUMMARY															STATUS		ASSIGNEE		REPORTER
Task	TU-35311	Initial Contacts agent implementation											To Do					Andy Kuszyk
Task	TU-35309	Initial automations agent implementation										To Do					Andy Kuszyk
Task	TU-35308	[MCP] List forms tool													To Do					Andy Kuszyk
Task	TU-35307	[MCP] Get form tool													To Do					Andy Kuszyk
Task	TU-35306	[MCP] Create form tool													To Do					Andy Kuszyk
EOF
fi
" 'utf-8-emacs name)
    (chmod name #o777)
    (message name)
    name))

(ert-deftest jira-cli-tbl-should-format-issues-as-table ()
  (let* ((jira-path (make-jira-cli)))
    (setq jira-cli-path jira-path)
    (jira-cli-tbl)
    (with-current-buffer (get-buffer "*jira*")
      (should (derived-mode-p 'tabulated-list-mode)))))

(ert-deftest jira-cli--parse-issue-reference-test ()
  (should (string=
	   (jira-cli--parse-issue-reference "Story	ABC-1127	Patching: ECS AMI				In Progress")
	   "ABC-1127"))
  (should (string=
	   (jira-cli--parse-issue-reference "TYPE	KEY		SUMMARY						STATUS")
	   nil))
  (should (string=
	   (jira-cli--parse-issue-reference "Epic	ABC-990		Compute - ECS Hardware Instance Modernisation	In Progress")
	   "ABC-990")))

(provide 'jira-cli-tests)
