# Keycloak-Scripts

---

# Windows

# Get Users with Groups Assigned

Filename: getUserPaginationWithGroups.bat

The final, main output file produced by the script is users_with_groups.json.
## Script Description:

### Fetch All Users:
The script starts by calling the Keycloak CLI to fetch all user records. This output is saved to all_users.json.

### Extract User IDs:
Using jq, the script extracts the id field from each user in all_users.json and writes those IDs to user_ids.json.

### Process Each User:
For every user ID in user_ids.json, the script:
Fetches the detailed user information.
Fetches the groups for that user.
Merges the user details and group information using jq into a single JSON object.

### Assemble Final Output:
Each merged user JSON object is appended into a JSON array in users_with_groups.json. This final file contains an array of user objects where each object includes the original user details along with a new "groups" field holding the array of group objects.

In summary, users_with_groups.json is your complete JSON output that aggregates user details and their associated groups in a structured, valid JSON array.
