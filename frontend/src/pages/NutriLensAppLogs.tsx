import { useEffect, useState } from "react";
import {
  Alert,
  Box,
  Button,
  Card,
  CardContent,
  CircularProgress,
  Chip,
  Collapse,
  Divider,
  Stack,
  TextField,
  Typography,
} from "@mui/material";
import RefreshIcon from "@mui/icons-material/Refresh";
import ExpandMoreIcon from "@mui/icons-material/ExpandMore";
import ExpandLessIcon from "@mui/icons-material/ExpandLess";
import { authApi } from "@services/api";
import { appLogsApi } from "@services/api";
import type { AppLogMeta, AppLogDetail } from "@services/api";

export default function NutriLensAppLogs() {
  const [isAdmin, setIsAdmin] = useState(false);
  const [checkedAdmin, setCheckedAdmin] = useState(false);
  const today = new Date().toISOString().split("T")[0];
  const [startDate, setStartDate] = useState(today);
  const [endDate, setEndDate] = useState(today);
  const [logs, setLogs] = useState<AppLogMeta[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [expandedId, setExpandedId] = useState<string | null>(null);
  const [detail, setDetail] = useState<AppLogDetail | null>(null);
  const [detailLoading, setDetailLoading] = useState(false);
  const [detailError, setDetailError] = useState("");

  // Check admin status on mount
  useEffect(() => {
    const username = localStorage.getItem("username") || "";
    if (!username) {
      setCheckedAdmin(true);
      return;
    }
    authApi
      .getUserDetail(username, "nutrilens")
      .then((detail) => {
        setIsAdmin(!!detail.is_admin);
      })
      .catch(() => {
        setIsAdmin(false);
      })
      .finally(() => setCheckedAdmin(true));
  }, []);

  const fetchLogs = async () => {
    setLoading(true);
    setError("");
    setLogs([]);
    setExpandedId(null);
    setDetail(null);
    try {
      const result = await appLogsApi.listLogs(startDate, endDate, 100);
      setLogs(result.logs);
    } catch (err: any) {
      const msg = err?.response?.data?.detail || "Failed to load logs";
      setError(String(msg));
    } finally {
      setLoading(false);
    }
  };

  // Load logs automatically once admin is confirmed
  useEffect(() => {
    if (checkedAdmin && isAdmin) {
      fetchLogs();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [checkedAdmin, isAdmin]);

  const toggleExpand = async (log: AppLogMeta) => {
    if (expandedId === log.log_id) {
      setExpandedId(null);
      setDetail(null);
      return;
    }
    setExpandedId(log.log_id);
    setDetail(null);
    setDetailError("");
    setDetailLoading(true);
    try {
      const dateHint = log.received_at ? log.received_at.split("T")[0] : undefined;
      const data = await appLogsApi.getLog(log.log_id, dateHint);
      setDetail(data);
    } catch (err: any) {
      const msg = err?.response?.data?.detail || "Failed to load log entry";
      setDetailError(String(msg));
    } finally {
      setDetailLoading(false);
    }
  };

  if (!checkedAdmin) {
    return (
      <Box sx={{ display: "flex", justifyContent: "center", mt: 8 }}>
        <CircularProgress />
      </Box>
    );
  }

  if (!isAdmin) {
    return (
      <Box sx={{ maxWidth: 600, mx: "auto", mt: 4, px: 2 }}>
        <Alert severity="error">Admin access required to view app logs.</Alert>
      </Box>
    );
  }

  return (
    <Box sx={{ maxWidth: 1100, mx: "auto", mt: { xs: 2, sm: 4 }, px: { xs: 2, sm: 3 } }}>
      <Card sx={{ p: { xs: 2, sm: 3 } }}>
        <Typography variant="h5" gutterBottom>
          App Logs
        </Typography>
        <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
          Diagnostic logs uploaded from the NutriLens mobile app. Admin access only.
        </Typography>

        <Stack direction={{ xs: "column", sm: "row" }} spacing={2} alignItems="flex-end" sx={{ mb: 3 }}>
          <TextField
            label="Start date"
            type="date"
            size="small"
            value={startDate}
            onChange={(e) => setStartDate(e.target.value)}
            InputLabelProps={{ shrink: true }}
            sx={{ minWidth: 180 }}
          />
          <TextField
            label="End date"
            type="date"
            size="small"
            value={endDate}
            onChange={(e) => setEndDate(e.target.value)}
            inputProps={{ min: startDate }}
            InputLabelProps={{ shrink: true }}
            sx={{ minWidth: 180 }}
          />
          <Button
            variant="outlined"
            startIcon={<RefreshIcon />}
            onClick={fetchLogs}
            disabled={loading}
          >
            Load Logs
          </Button>
        </Stack>

        {loading && (
          <Box sx={{ display: "flex", justifyContent: "center", py: 4 }}>
            <CircularProgress />
          </Box>
        )}

        {!loading && error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}

        {!loading && !error && logs.length === 0 && (
          <Alert severity="info">No logs found for {startDate}{startDate !== endDate ? ` – ${endDate}` : ""}.</Alert>
        )}

        {!loading && !error && logs.length > 0 && (
          <Stack spacing={1}>
            {logs.map((log) => (
              <Card key={log.log_id} variant="outlined">
                <CardContent sx={{ pb: "12px !important" }}>
                  <Stack
                    direction={{ xs: "column", sm: "row" }}
                    alignItems={{ sm: "center" }}
                    justifyContent="space-between"
                    spacing={1}
                  >
                    <Box sx={{ flex: 1, minWidth: 0 }}>
                      <Stack direction="row" spacing={1} flexWrap="wrap" alignItems="center">
                        {log.platform && (
                          <Chip label={log.platform} size="small" color="primary" variant="outlined" />
                        )}
                        {log.environment && (
                          <Chip label={log.environment} size="small" />
                        )}
                        {log.log_scope && (
                          <Chip label={log.log_scope} size="small" variant="outlined" />
                        )}
                        {log.app_version && (
                          <Typography variant="caption" color="text.secondary">
                            v{log.app_version}
                          </Typography>
                        )}
                      </Stack>
                      <Typography variant="body2" sx={{ mt: 0.5 }}>
                        {log.user_identity ?? "anonymous"}{" "}
                        <Typography component="span" variant="caption" color="text.secondary">
                          {log.received_at ? new Date(log.received_at + "Z").toLocaleString() : ""}
                        </Typography>
                      </Typography>
                      <Typography
                        variant="caption"
                        color="text.secondary"
                        sx={{ fontFamily: "monospace", wordBreak: "break-all" }}
                      >
                        {log.log_id}
                      </Typography>
                    </Box>
                    <Button
                      size="small"
                      endIcon={expandedId === log.log_id ? <ExpandLessIcon /> : <ExpandMoreIcon />}
                      onClick={() => toggleExpand(log)}
                    >
                      {expandedId === log.log_id ? "Hide" : "View"}
                    </Button>
                  </Stack>

                  <Collapse in={expandedId === log.log_id} unmountOnExit>
                    <Divider sx={{ my: 1.5 }} />
                    {detailLoading && (
                      <Box sx={{ display: "flex", justifyContent: "center", py: 2 }}>
                        <CircularProgress size={24} />
                      </Box>
                    )}
                    {!detailLoading && detailError && (
                      <Alert severity="error" sx={{ mb: 1 }}>
                        {detailError}
                      </Alert>
                    )}
                    {!detailLoading && detail && expandedId === log.log_id && (
                      <Box
                        component="pre"
                        sx={{
                          whiteSpace: "pre-wrap",
                          wordBreak: "break-word",
                          fontSize: "0.75rem",
                          fontFamily: "monospace",
                          bgcolor: "grey.50",
                          border: "1px solid",
                          borderColor: "grey.200",
                          borderRadius: 1,
                          p: 1.5,
                          maxHeight: 400,
                          overflowY: "auto",
                        }}
                      >
                        {detail.logs}
                      </Box>
                    )}
                  </Collapse>
                </CardContent>
              </Card>
            ))}
          </Stack>
        )}
      </Card>
    </Box>
  );
}
