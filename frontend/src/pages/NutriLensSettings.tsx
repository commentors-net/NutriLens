import { useEffect, useState } from "react";
import {
  Alert,
  Box,
  Button,
  Card,
  CardContent,
  CircularProgress,
  Divider,
  FormControl,
  Grid,
  InputLabel,
  MenuItem,
  Select,
  Stack,
  TextField,
  Typography,
} from "@mui/material";
import SaveIcon from "@mui/icons-material/Save";
import RefreshIcon from "@mui/icons-material/Refresh";
import { authApi } from "@services/api";
import type { NutriLensSystemSettings } from "@services/api";

export default function NutriLensSettings() {
  const [settings, setSettings] = useState<NutriLensSystemSettings>({
    local_ai_url: "http://192.168.0.200:11434",
    local_ai_model: "llama3.2-vision",
    local_ai_timeout_seconds: 90,
    gemini_model: "gemini-2.5-flash",
    gemini_timeout_seconds: 15,
    default_locale: "en_MY",
    default_currency: "MYR",
    unit_system: "metric",
    default_calorie_goal: 2000,
    default_protein_goal_g: 100.0,
    default_carbs_goal_g: 250.0,
    default_fat_goal_g: 65.0,
  });

  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [successMsg, setSuccessMsg] = useState("");
  const [errorMsg, setErrorMsg] = useState("");

  const fetchSettings = async () => {
    setLoading(true);
    setErrorMsg("");
    try {
      const data = await authApi.getSystemSettings("nutrilens");
      setSettings(data);
    } catch (err: any) {
      setErrorMsg(err?.response?.data?.detail || "Failed to load system settings");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchSettings();
  }, []);

  const handleSave = async (e: React.FormEvent) => {
    e.preventDefault();
    setSaving(true);
    setSuccessMsg("");
    setErrorMsg("");
    try {
      const updated = await authApi.updateSystemSettings(settings, "nutrilens");
      setSettings(updated);
      setSuccessMsg("System configuration saved successfully!");
      setTimeout(() => setSuccessMsg(""), 4000);
    } catch (err: any) {
      setErrorMsg(err?.response?.data?.detail || "Failed to update system settings");
    } finally {
      setSaving(false);
    }
  };

  return (
    <Box sx={{ maxWidth: 1000, mx: "auto", mt: { xs: 2, sm: 4 }, px: { xs: 2, sm: 3 }, pb: 6 }}>
      <Typography variant="h5" sx={{ fontWeight: 700, mb: 1 }}>
        NutriLens System Settings
      </Typography>
      <Typography variant="body2" color="text.secondary" sx={{ mb: 3 }}>
        Manage platform-wide configurations, AI endpoint defaults, localization, and nutritional baselines.
      </Typography>

      {successMsg && <Alert severity="success" sx={{ mb: 3 }}>{successMsg}</Alert>}
      {errorMsg && <Alert severity="error" sx={{ mb: 3 }}>{errorMsg}</Alert>}

      {loading ? (
        <Box sx={{ display: "flex", justifyContent: "center", py: 6 }}>
          <CircularProgress />
        </Box>
      ) : (
        <form onSubmit={handleSave}>
          <Stack spacing={3}>
            {/* Local AI Configuration Card */}
            <Card variant="outlined">
              <CardContent>
                <Typography variant="h6" sx={{ fontWeight: 600, color: "primary.main", mb: 1 }}>
                  Local AI Agent (Ollama LAN)
                </Typography>
                <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
                  Configure the default local vision agent endpoint and model for users with Deep Local AI access.
                </Typography>
                <Divider sx={{ mb: 2 }} />

                <Grid container spacing={2}>
                  <Grid size={{ xs: 12, sm: 6 }}>
                    <TextField
                      fullWidth
                      label="Local AI Host Endpoint"
                      value={settings.local_ai_url}
                      onChange={(e) => setSettings({ ...settings, local_ai_url: e.target.value })}
                      helperText="e.g. http://192.168.0.200:11434"
                      size="small"
                      required
                    />
                  </Grid>
                  <Grid size={{ xs: 12, sm: 3 }}>
                    <TextField
                      fullWidth
                      label="Vision Model Name"
                      value={settings.local_ai_model}
                      onChange={(e) => setSettings({ ...settings, local_ai_model: e.target.value })}
                      helperText="e.g. llama3.2-vision"
                      size="small"
                      required
                    />
                  </Grid>
                  <Grid size={{ xs: 12, sm: 3 }}>
                    <TextField
                      fullWidth
                      label="Timeout (seconds)"
                      type="number"
                      value={settings.local_ai_timeout_seconds}
                      onChange={(e) =>
                        setSettings({ ...settings, local_ai_timeout_seconds: parseInt(e.target.value) || 90 })
                      }
                      size="small"
                    />
                  </Grid>
                </Grid>
              </CardContent>
            </Card>

            {/* Cloud Vision Configuration Card */}
            <Card variant="outlined">
              <CardContent>
                <Typography variant="h6" sx={{ fontWeight: 600, color: "primary.main", mb: 1 }}>
                  Cloud Vision (Google Gemini)
                </Typography>
                <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
                  Parameters for primary fast vision analysis and supreme consensus arbitration.
                </Typography>
                <Divider sx={{ mb: 2 }} />

                <Grid container spacing={2}>
                  <Grid size={{ xs: 12, sm: 8 }}>
                    <FormControl fullWidth size="small">
                      <InputLabel>Gemini Vision Model</InputLabel>
                      <Select
                        value={settings.gemini_model}
                        label="Gemini Vision Model"
                        onChange={(e) => setSettings({ ...settings, gemini_model: e.target.value })}
                      >
                        <MenuItem value="gemini-2.5-flash">gemini-2.5-flash (Recommended, Balanced)</MenuItem>
                        <MenuItem value="gemini-2.5-flash-lite">gemini-2.5-flash-lite (Ultra-fast, Cost-efficient)</MenuItem>
                        <MenuItem value="gemini-1.5-flash">gemini-1.5-flash (Legacy)</MenuItem>
                      </Select>
                    </FormControl>
                  </Grid>
                  <Grid size={{ xs: 12, sm: 4 }}>
                    <TextField
                      fullWidth
                      label="Timeout (seconds)"
                      type="number"
                      value={settings.gemini_timeout_seconds}
                      onChange={(e) =>
                        setSettings({ ...settings, gemini_timeout_seconds: parseInt(e.target.value) || 15 })
                      }
                      size="small"
                    />
                  </Grid>
                </Grid>
              </CardContent>
            </Card>

            {/* Regional & Localization Defaults */}
            <Card variant="outlined">
              <CardContent>
                <Typography variant="h6" sx={{ fontWeight: 600, color: "primary.main", mb: 1 }}>
                  Localization & Regional Standards
                </Typography>
                <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
                  Default regional conventions when not overridden by the user device.
                </Typography>
                <Divider sx={{ mb: 2 }} />

                <Grid container spacing={2}>
                  <Grid size={{ xs: 12, sm: 4 }}>
                    <FormControl fullWidth size="small">
                      <InputLabel>Default Locale</InputLabel>
                      <Select
                        value={settings.default_locale}
                        label="Default Locale"
                        onChange={(e) => setSettings({ ...settings, default_locale: e.target.value })}
                      >
                        <MenuItem value="en_MY">en_MY (Malaysia)</MenuItem>
                        <MenuItem value="ms_MY">ms_MY (Bahasa Melayu)</MenuItem>
                        <MenuItem value="en_SG">en_SG (Singapore)</MenuItem>
                        <MenuItem value="en_US">en_US (United States)</MenuItem>
                        <MenuItem value="en_GB">en_GB (United Kingdom)</MenuItem>
                      </Select>
                    </FormControl>
                  </Grid>
                  <Grid size={{ xs: 12, sm: 4 }}>
                    <FormControl fullWidth size="small">
                      <InputLabel>Currency</InputLabel>
                      <Select
                        value={settings.default_currency}
                        label="Currency"
                        onChange={(e) => setSettings({ ...settings, default_currency: e.target.value })}
                      >
                        <MenuItem value="MYR">MYR (RM)</MenuItem>
                        <MenuItem value="SGD">SGD (S$)</MenuItem>
                        <MenuItem value="USD">USD ($)</MenuItem>
                        <MenuItem value="EUR">EUR (€)</MenuItem>
                        <MenuItem value="GBP">GBP (£)</MenuItem>
                      </Select>
                    </FormControl>
                  </Grid>
                  <Grid size={{ xs: 12, sm: 4 }}>
                    <FormControl fullWidth size="small">
                      <InputLabel>Unit System</InputLabel>
                      <Select
                        value={settings.unit_system}
                        label="Unit System"
                        onChange={(e) => setSettings({ ...settings, unit_system: e.target.value })}
                      >
                        <MenuItem value="metric">Metric (grams, ml, kg)</MenuItem>
                        <MenuItem value="imperial">Imperial (ounces, fl oz, lbs)</MenuItem>
                      </Select>
                    </FormControl>
                  </Grid>
                </Grid>
              </CardContent>
            </Card>

            {/* Default Nutritional Targets */}
            <Card variant="outlined">
              <CardContent>
                <Typography variant="h6" sx={{ fontWeight: 600, color: "primary.main", mb: 1 }}>
                  Baseline Nutritional Goals
                </Typography>
                <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
                  Default daily calorie and macro goals applied to new NutriLens user accounts.
                </Typography>
                <Divider sx={{ mb: 2 }} />

                <Grid container spacing={2}>
                  <Grid size={{ xs: 6, sm: 3 }}>
                    <TextField
                      fullWidth
                      label="Daily Calories (kcal)"
                      type="number"
                      value={settings.default_calorie_goal}
                      onChange={(e) =>
                        setSettings({ ...settings, default_calorie_goal: parseInt(e.target.value) || 2000 })
                      }
                      size="small"
                    />
                  </Grid>
                  <Grid size={{ xs: 6, sm: 3 }}>
                    <TextField
                      fullWidth
                      label="Protein Goal (g)"
                      type="number"
                      value={settings.default_protein_goal_g}
                      onChange={(e) =>
                        setSettings({ ...settings, default_protein_goal_g: parseFloat(e.target.value) || 100 })
                      }
                      size="small"
                    />
                  </Grid>
                  <Grid size={{ xs: 6, sm: 3 }}>
                    <TextField
                      fullWidth
                      label="Carbs Goal (g)"
                      type="number"
                      value={settings.default_carbs_goal_g}
                      onChange={(e) =>
                        setSettings({ ...settings, default_carbs_goal_g: parseFloat(e.target.value) || 250 })
                      }
                      size="small"
                    />
                  </Grid>
                  <Grid size={{ xs: 6, sm: 3 }}>
                    <TextField
                      fullWidth
                      label="Fat Goal (g)"
                      type="number"
                      value={settings.default_fat_goal_g}
                      onChange={(e) =>
                        setSettings({ ...settings, default_fat_goal_g: parseFloat(e.target.value) || 65 })
                      }
                      size="small"
                    />
                  </Grid>
                </Grid>
              </CardContent>
            </Card>

            {/* Action Buttons */}
            <Stack direction="row" spacing={2} justifyContent="flex-end">
              <Button
                variant="outlined"
                startIcon={<RefreshIcon />}
                onClick={fetchSettings}
                disabled={loading || saving}
              >
                Reset
              </Button>
              <Button
                type="submit"
                variant="contained"
                startIcon={saving ? <CircularProgress size={20} color="inherit" /> : <SaveIcon />}
                disabled={loading || saving}
              >
                {saving ? "Saving..." : "Save Settings"}
              </Button>
            </Stack>
          </Stack>
        </form>
      )}
    </Box>
  );
}
