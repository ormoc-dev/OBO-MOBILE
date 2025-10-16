# API Endpoint Requirement

## New Endpoint Needed

To support user-specific data syncing, you need to create a new API endpoint on your server:

### Endpoint: `/mobile/get_user_assignments.php`

**Method:** GET  
**Parameters:** `inspector_role_id` (query parameter)

**Example URL:**
```
GET /mobile/get_user_assignments.php?inspector_role_id=123
```

### Expected Response Format

```json
{
  "success": true,
  "message": "Assignments retrieved successfully",
  "data": {
    "assignments": [
      {
        "assignment_id": 1,
        "status": "assigned",
        "inspection_date": "2024-01-15",
        "completion_date": null,
        "assigned_at": "2024-01-10T10:00:00Z",
        "assignment_notes": "Initial inspection required",
        "business_assignment_id": 101,
        "business_id": "BUS001",
        "business_name": "Sample Business",
        "business_address": "123 Main St",
        "business_notes": "Regular inspection",
        "department_name": "Building Department",
        "department_description": "Building inspections",
        "assigned_by_name": "Admin User",
        "assigned_by_admin": "admin@example.com"
      }
    ]
  }
}
```

### Error Response Format

```json
{
  "success": false,
  "message": "No assignments found for this inspector",
  "data": null
}
```

### Implementation Notes

1. **Authentication:** The endpoint should verify that the user is logged in and has permission to access their assignments.

2. **Filtering:** Only return assignments where the `inspector_role_id` matches the provided parameter.

3. **Security:** Ensure that users can only access their own assignments, not other users' data.

4. **Database Query:** The query should filter assignments based on the inspector's role ID.

### Example PHP Implementation

```php
<?php
header('Content-Type: application/json');
session_start();

// Check if user is logged in
if (!isset($_SESSION['user_id'])) {
    echo json_encode([
        'success' => false,
        'message' => 'Not logged in',
        'data' => null
    ]);
    exit;
}

$inspector_role_id = $_GET['inspector_role_id'] ?? null;

if (!$inspector_role_id) {
    echo json_encode([
        'success' => false,
        'message' => 'Inspector role ID is required',
        'data' => null
    ]);
    exit;
}

// Verify user has permission to access this inspector's data
$user_id = $_SESSION['user_id'];
$user_role = $_SESSION['user_role'];

// If not admin, ensure user can only access their own data
if ($user_role !== 'admin') {
    $user_inspector_role = $_SESSION['inspector_role_id'];
    if ($user_inspector_role != $inspector_role_id) {
        echo json_encode([
            'success' => false,
            'message' => 'Access denied',
            'data' => null
        ]);
        exit;
    }
}

// Database query to get assignments for the inspector
$sql = "SELECT * FROM assignments WHERE inspector_role_id = ?";
$stmt = $pdo->prepare($sql);
$stmt->execute([$inspector_role_id]);
$assignments = $stmt->fetchAll(PDO::FETCH_ASSOC);

echo json_encode([
    'success' => true,
    'message' => 'Assignments retrieved successfully',
    'data' => [
        'assignments' => $assignments
    ]
]);
?>
```

## Offline Login Support

The mobile app now supports offline login by storing user credentials securely when they sync their data. This allows users to:

1. **Sync their data** → Stores assignments + credentials
2. **Login offline** → Uses stored credentials for authentication
3. **Access assignments** → View and work with synced data offline

### Credential Storage

When a user syncs their data, the following information is stored securely:

```json
{
  "username": "john_doe",
  "user_id": 123,
  "inspector_role_id": "INSP001",
  "role": "inspector",
  "status": "active",
  "synced_at": "2024-01-15T10:30:00Z"
}
```

### Security Notes

- **No passwords stored:** Only user identification data is stored
- **Encrypted storage:** Credentials are stored securely in device storage
- **Automatic cleanup:** Credentials are cleared when user logs out or clears data

## Benefits of This Approach

1. **Security:** Users can only access their own data
2. **Performance:** Only relevant data is downloaded
3. **Scalability:** Reduces server load and bandwidth usage
4. **User Experience:** Faster sync times for individual users
5. **Privacy:** Ensures data privacy and compliance
6. **Offline Access:** Users can login and work offline after syncing

## Migration Path

1. **Phase 1:** Create the new endpoint
2. **Phase 2:** Update the mobile app to use the new endpoint
3. **Phase 3:** Test with different user roles
4. **Phase 4:** Remove or deprecate the old admin-only endpoints if no longer needed
