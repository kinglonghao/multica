#!/usr/bin/env python3
import os
import re

# List of files to update
files = [
    "./entry/src/main/ets/pages/IssueDetailPage.ets",
    "./entry/src/main/ets/pages/SearchPage.ets",
    "./entry/src/main/ets/pages/VerifyPage.ets",
    "./entry/src/main/ets/pages/MorePage.ets",
    "./entry/src/main/ets/pages/ChatPage.ets",
    "./entry/src/main/ets/pages/MyIssuesPage.ets",
    "./entry/src/main/ets/pages/ChatDetailPage.ets",
    "./entry/src/main/ets/pages/LoginPage.ets",
    "./entry/src/main/ets/pages/SelectWorkspacePage.ets",
    "./entry/src/main/ets/pages/WorkspaceLayout.ets",
    "./entry/src/main/ets/pages/AgentsPage.ets",
    "./entry/src/main/ets/pages/InboxPage.ets",
    "./entry/src/main/ets/pages/ProjectDetailPage.ets",
    "./entry/src/main/ets/pages/ProfilePage.ets",
    "./entry/src/main/ets/pages/SwitchWorkspacePage.ets",
    "./entry/src/main/ets/pages/NotificationsPage.ets"
]

# Already processed
# "./entry/src/main/ets/pages/NewIssuePage.ets",
# "./entry/src/main/ets/pages/Index.ets",

for file_path in files:
    print(f"Processing {file_path}")
    
    # Read the file
    with open(file_path, 'r') as f:
        content = f.read()
    
    # Check if already has detectSystemColorScheme import
    if 'detectSystemColorScheme' in content:
        print(f"  Already has detectSystemColorScheme import")
        continue
    
    # Add import after theme import
    # Look for import lines containing '../lib/theme'
    lines = content.split('\n')
    new_lines = []
    theme_import_added = False
    
    for i, line in enumerate(lines):
        new_lines.append(line)
        # Check if this line imports ColorScheme from theme
        if ('from \'../lib/theme\'' in line or 'from "../lib/theme"' in line) and not theme_import_added:
            # Add import for detectSystemColorScheme
            new_lines.append('import { detectSystemColorScheme } from \'../lib/theme-manager\';')
            theme_import_added = True
    
    # Update detectScheme method
    updated_content = '\n'.join(new_lines)
    
    # Replace detectScheme method
    updated_content = re.sub(
        r'private detectScheme\(\): ColorScheme \{\s*return \'light\';\s*\}',
        '  private detectScheme(): ColorScheme {\n    return detectSystemColorScheme();\n  }',
        updated_content
    )
    
    # Write back
    with open(file_path, 'w') as f:
        f.write(updated_content)
    
    print(f"  Updated {file_path}")

print("Done!")