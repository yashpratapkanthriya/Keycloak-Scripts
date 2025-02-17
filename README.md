# Keycloak-Scripts

JQ download link: [Download⬇️](https://jqlang.org/download/) 

---

# Windows

# 1. Get Users with Groups Assigned

Filename: getUserPaginationWithGroups.bat

The final, main output file produced by the script is users_with_groups.json.

---

### **Script Overview**

This batch script is designed to export all users (with their associated groups) from a Keycloak realm in a paginated fashion, then merge the results into a single JSON file. It uses the Keycloak Admin CLI (`kcadm.bat`) for API calls and **jq** for JSON processing. The script is particularly useful when you have a large number of users (e.g., 2000+) and need to handle pagination automatically.

---

### **Key Steps in the Script**

1. **Configuration & Initialization:**  
   - **Variables:**  
     - **LOGFILE:** Log file path to capture detailed execution logs.  
     - **KEYCLOAK_BIN:** Path to the Keycloak Admin CLI executable (`kcadm.bat`).  
     - **JQ_EXE:** Path to the **jq** executable for JSON processing.  
     - **SERVER_URL:** The URL of the Keycloak server (e.g., `http://localhost:8080/auth`).  
     - **AUTH_REALM:** Realm used for authentication (commonly `master`).  
     - **TARGET_REALM:** Realm from which users are retrieved (e.g., `singleRealm`).  
     - **ADMIN_USER / ADMIN_PASS:** Admin credentials for authenticating with Keycloak.  
     - **pageSize:** Number of users to retrieve per page (set to 100).
   - **Logging:**  
     The script starts by logging its start time to `users_with_groups.log`.

2. **Authentication:**  
   - The script authenticates to Keycloak using the admin credentials and the authentication realm (`AUTH_REALM`).  
   - This is necessary to obtain a valid session token for subsequent API calls.

3. **Fetching the Total User Count:**  
   - The script calls the `/users/count` endpoint against the **TARGET_REALM** to retrieve the total number of users.  
   - The returned count is saved in `user_count.json` and then read into a variable (`userCount`).  
   - Using this count and the predefined page size, the script calculates the total number of pages needed (rounding up if necessary).

4. **Pagination – Fetching Users in Batches:**  
   - A loop (pagination loop) iterates over each page:
     - **Re-Authentication:** Before each paginated API call, the script re-authenticates to refresh the session.
     - **Offset & Limit:** The script uses the dedicated pagination options:
       - **`-o` (offset):** Sets the starting index (passed as the `first` query parameter).
       - **`-l` (limit):** Sets the maximum number of users to retrieve (passed as the `max` query parameter).
     - Each API call retrieves a batch of users (100 per call) and saves the output to a file (e.g., `page_0.json`, `page_1.json`, etc.).
     - The loop stops when all pages have been fetched or if a page returns an empty file.

5. **Aggregating Paginated Files:**  
   - Once all pages are fetched, the script uses **jq** with the `-s "add"` option to merge all page JSON files into one single aggregated file (`all_users_full.json`).

6. **Extracting User IDs:**  
   - The script then extracts the `id` field from each user in the aggregated file using **jq**.
   - The resulting list of user IDs is stored in `user_ids.json`.

7. **Processing Each User:**  
   - For every user ID found in `user_ids.json`, the script calls a subroutine (`:process_user`) that:
     - **Fetches User Details:** Retrieves the full user record using the `get users/{id}` endpoint.
     - **Fetches User Groups:** Retrieves the list of groups associated with that user.
     - **Merges Data:** Uses **jq** to merge the user details with the groups into one JSON object.
     - **Appending to Final Output:** Appends the merged JSON for each user to a file called `users_with_groups.json`, building a JSON array.

8. **Final Output:**  
   - The main output file of the script is **`users_with_groups.json`**.  
   - This file contains a JSON array where each element is an object representing a user, complete with their detailed information and an added `"groups"` field that holds the user’s groups.

9. **Logging & Clean-up:**  
   - Throughout the process, detailed logs are written to `users_with_groups.log` with timestamps to help troubleshoot any issues.
   - Optionally, intermediate page files are deleted after aggregation.

---

### **Usage Summary**

- **Purpose:**  
  To export a complete list of users (and their associated groups) from a specified Keycloak realm, handling pagination automatically when there are more users than can be returned in a single API call.

- **Main Output:**  
  The final output is a JSON file named **`users_with_groups.json`**, which contains an array of user objects enriched with their group data.

- **Requirements:**  
  - Keycloak Admin CLI (`kcadm.bat`) must be properly configured and accessible.
  - **jq** must be installed and available at the specified path.
  - Valid admin credentials for authentication.
  - The target realm (from which users are fetched) must exist.

---

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
