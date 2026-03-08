import { useEffect, useMemo, useState } from "react";
import {
  Alert,
  Box,
  Button,
  Card,
  CardContent,
  Checkbox,
  CircularProgress,
  FormControlLabel,
  Stack,
  Typography,
} from "@mui/material";
import { authApi } from "@services/api";
import type { UserAccessItem } from "@services/api";

interface UserDetail extends UserAccessItem {
  is_admin?: boolean;
}

export default function NutriLensUsers() {
  const [users, setUsers] = useState<UserDetail[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [savingUser, setSavingUser] = useState("");

  const sortedUsers = useMemo(
    () => [...users].sort((a, b) => a.username.localeCompare(b.username)),
    [users],
  );

  const fetchUsers = async () => {
    setLoading(true);
    setError("");
    try {
      const accessData = await authApi.listUserAccess("nutrilens");
      // Fetch admin status for each user
      const enriched = await Promise.all(
        accessData.map(async (user) => {
          try {
            const detail = await authApi.getUserDetail(user.username, "nutrilens");
            return {
              ...user,
              is_admin: detail.is_admin,
            };
          } catch {
            // If we can't get admin status, assume false
            return {
              ...user,
              is_admin: false,
            };
          }
        }),
      );
      setUsers(enriched);
    } catch (err: any) {
      const message = err?.response?.data?.detail || "Failed to load user access list";
      setError(String(message));
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchUsers();
  }, []);

  const toggleSystem = async (user: UserDetail, system: "leave-tracker" | "nutrilens") => {
    const hasSystem = user.allowed_systems.includes(system);
    const updated = hasSystem
      ? user.allowed_systems.filter((s) => s !== system)
      : [...user.allowed_systems, system];

    if (updated.length === 0) {
      alert("A user must have at least one system enabled.");
      return;
    }

    setSavingUser(user.username);
    try {
      const saved = await authApi.updateUserAccess(
        user.username,
        { allowed_systems: updated },
        "nutrilens",
      );
      setUsers((prev) =>
        prev.map((u) => (u.username === user.username ? { ...saved, is_admin: u.is_admin } : u)),
      );
    } catch (err: any) {
      const message = err?.response?.data?.detail || "Failed to update user access";
      alert(message);
    } finally {
      setSavingUser("");
    }
  };

  const toggleAdminStatus = async (user: UserDetail) => {
    const newStatus = !user.is_admin;
    setSavingUser(user.username);
    try {
      await authApi.updateUserAdminStatus(
        user.username,
        { is_admin: newStatus },
        "nutrilens",
      );
      setUsers((prev) =>
        prev.map((u) =>
          u.username === user.username ? { ...u, is_admin: newStatus } : u,
        ),
      );
    } catch (err: any) {
      const message = err?.response?.data?.detail || "Failed to update admin status";
      alert(message);
    } finally {
      setSavingUser("");
    }
  };

  return (
    <Box sx={{ maxWidth: 1000, mx: "auto", mt: { xs: 2, sm: 4 }, px: { xs: 2, sm: 3 } }}>
      <Card sx={{ p: { xs: 2, sm: 3 } }}>
        <Typography variant="h5" gutterBottom>
          User Management
        </Typography>
        <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
          Manage user system access and admin roles. Only admin users can access this page.
        </Typography>

        <Stack direction="row" spacing={2} sx={{ mb: 2 }}>
          <Button variant="outlined" onClick={fetchUsers} disabled={loading}>
            Refresh
          </Button>
        </Stack>

        {loading && (
          <Box sx={{ display: "flex", justifyContent: "center", py: 4 }}>
            <CircularProgress />
          </Box>
        )}

        {!loading && error && <Alert severity="error">{error}</Alert>}

        {!loading && !error && sortedUsers.length === 0 && (
          <Alert severity="info">No users found.</Alert>
        )}

        {!loading && !error && sortedUsers.length > 0 && (
          <Stack spacing={2}>
            {sortedUsers.map((user) => (
              <Card key={user.user_id} variant="outlined">
                <CardContent>
                  <Stack direction={{ xs: "column", sm: "row" }} justifyContent="space-between" alignItems={{ xs: "flex-start", sm: "center" }} spacing={2}>
                    <Box>
                      <Typography variant="subtitle1" sx={{ fontWeight: 600 }}>
                        {user.username}
                      </Typography>
                      {user.is_admin && (
                        <Typography variant="caption" sx={{ color: "primary.main", fontWeight: 500 }}>
                          Admin
                        </Typography>
                      )}
                    </Box>
                    <Stack direction={{ xs: "column", sm: "row" }} spacing={2} sx={{ minWidth: { sm: "300px" } }}>
                      <FormControlLabel
                        control={
                          <Checkbox
                            checked={user.allowed_systems.includes("leave-tracker")}
                            onChange={() => toggleSystem(user, "leave-tracker")}
                            disabled={savingUser === user.username}
                            size="small"
                          />
                        }
                        label="Leave Tracker"
                        sx={{ mb: 0 }}
                      />
                      <FormControlLabel
                        control={
                          <Checkbox
                            checked={user.allowed_systems.includes("nutrilens")}
                            onChange={() => toggleSystem(user, "nutrilens")}
                            disabled={savingUser === user.username}
                            size="small"
                          />
                        }
                        label="NutriLens"
                        sx={{ mb: 0 }}
                      />
                      <FormControlLabel
                        control={
                          <Checkbox
                            checked={user.is_admin || false}
                            onChange={() => toggleAdminStatus(user)}
                            disabled={savingUser === user.username}
                            size="small"
                          />
                        }
                        label="Admin"
                        sx={{ mb: 0 }}
                      />
                      {savingUser === user.username && <CircularProgress size={20} sx={{ alignSelf: "center" }} />}
                    </Stack>
                  </Stack>
                </CardContent>
              </Card>
            ))}
          </Stack>
        )}
      </Card>
    </Box>
  );
}

