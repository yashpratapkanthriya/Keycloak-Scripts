# Keycloak-Scripts

---

# Windows

# 1. Get Users with Groups Assigned

Filename: getUserPaginationWithGroups.bat

The final, main output file produced by the script is users_with_groups.json.
## Script Description:

### Fetch Count of Users:
The script starts by calling the Keycloak CLI to fetch the count of all user records.

### Fetch All Users:
The script then calls the Keycloak CLI to fetch all user records with pagination. This output is saved to all_users.json.

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

# 2. Create users with specific Group

Filename: createUserWithGroup.bat

Below is a detailed description of the script we created:

---

### Script Overview

This batch script automates the process of creating 120 new users in a Keycloak realm and assigning each user to a specified group (in this case, "SuperUsers"). It uses the Keycloak Admin CLI (kcadm.bat) and **jq** for JSON processing. The script also logs its progress to a logfile so you can review each step and any errors that occur.

---

### Detailed Description of Each Section

1. **Configuration & Initialization**

   - **Variables:**  
     The script sets several environment variables:
     - `LOGFILE`: The file where the script logs its actions (e.g., `userscreated.log`).
     - `KEYCLOAK_BIN`: Path to the Keycloak Admin CLI executable.
     - `JQ_EXE`: Path to the **jq** executable for JSON processing.
     - `SERVER_URL`: URL of the Keycloak server (including `/auth`).
     - `REALM`: The realm in which the operations will occur (e.g., `master`).
     - `GROUP_NAME`: The name of the group to which new users will be added (e.g., "SuperUsers").
     - `ADMIN_USER` and `ADMIN_PASS`: The admin credentials used for authentication.
     - `EMPTY_JSON`: The path to a file (named `empty.json`) containing a minimal JSON object (`{}`) used for the group assignment command.

   - **Log Start:**  
     The script writes a start message with the current date and time into the log file.

2. **Authentication**

   - **Keycloak Login:**  
     The script calls the Keycloak CLI with the `config credentials` command to log in to the Keycloak server using the provided admin credentials. This step ensures that the session is refreshed and valid for subsequent commands.

   - **Error Check:**  
     If authentication fails (checked by `%ERRORLEVEL%`), the script logs an error and exits.

3. **Fetching All Groups**

   - **Retrieve Groups:**  
     The script calls the Keycloak CLI to get all groups from the specified realm. The output is written in JSON format to a file named `all_groups.json`.

   - **Error Check:**  
     If fetching groups fails, the script logs an error and exits.

4. **Selecting the Target Group**

   - **Extracting Group ID:**  
     Using **jq**, the script processes `all_groups.json` to search for the group whose name matches the `GROUP_NAME` variable. It extracts that group's ID.
     
   - **Error Check:**  
     If the group isn’t found (i.e., `GROUP_ID` remains empty), the script logs an error and exits.

5. **User Creation and Group Assignment Loop**

   - **Loop Over 120 Iterations:**  
     A `for` loop iterates from 1 to 120. For each iteration:
     
     - **Username and Email Formatting:**  
       Depending on the number, a new user is given a name formatted as `user001`, `user002`, ..., `user120`, and an associated email is generated.
     
     - **Creating the User:**  
       The script calls the Keycloak CLI with the `create users` command. It supplies user attributes such as username, email, enabled status, and a default password (e.g., "Password123"). Note that this command does not use the unsupported `--format json` option.
     
     - **User Creation Error Check:**  
       If user creation fails, an error is logged, and that iteration is skipped.
     
     - **Retrieving the User ID:**  
       After waiting briefly to ensure the user is created, the script retrieves the new user's ID by querying for that username. The output is parsed using **jq** to extract the first object's ID.
     
     - **User ID Check:**  
       If the ID can’t be retrieved, the script logs an error and skips the group assignment for that user.
     
     - **Adding the User to the Group:**  
       Using the retrieved user ID and the group ID (from earlier), the script calls the Keycloak CLI with the `update users/{user_id}/groups/{group_id}` command.  
       Instead of passing `NUL` (which caused errors on Windows), the script uses a file named `empty.json` (which must contain `{}`) to satisfy the `--file` requirement.
     
     - **Logging Outcome:**  
       The script logs whether the group assignment was successful or if there was an error.
     
     - **Iteration Separator:**  
       A separator line is logged to make the log easier to read between iterations.

6. **Completion**

   - **Log End:**  
     After the loop completes, the script logs that it has finished creating users and adding them to the group, along with a timestamp.
     
   - **Pause:**  
     The script then pauses so you can review the results in the command prompt.

---

### Summary

- **Purpose:** Automatically create 120 users and assign them to the "SuperUsers" group in the specified realm.
- **Tools Used:**  
  - Keycloak Admin CLI (`kcadm.bat`) for interacting with the Keycloak server.  
  - **jq** for processing JSON responses.
- **Error Handling:** The script logs errors at each step and uses conditional checks to exit or skip iterations when errors occur.
- **Logging:** All actions and errors are logged to a logfile (`userscreated.log`), making it easier to troubleshoot and verify each step.
- **File Requirement:** The script uses an `empty.json` file (which should contain `{}`) to work around a CLI requirement when adding users to a group.

This detailed description explains each part of the script and how it achieves the desired automation in Keycloak.
