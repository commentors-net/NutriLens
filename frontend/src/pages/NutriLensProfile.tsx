import { useState, useEffect } from "react";
import {
  Card,
  TextField,
  Button,
  Typography,
  Box,
  Alert,
  Stack,
  Chip,
  LinearProgress,
} from "@mui/material";
import { authApi } from "@services/api";

interface NutriLensProfile {
  username: string;
  daily_calorie_goal: number;
  protein_goal_g: number;
  carbs_goal_g: number;
  fat_goal_g: number;
  dietary_restrictions: string[];
}

export default function NutriLensProfile() {
  const [profile, setProfile] = useState<NutriLensProfile | null>(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState(false);
  const [restrictionInput, setRestrictionInput] = useState("");

  useEffect(() => {
    loadProfile();
  }, []);

  const loadProfile = async () => {
    try {
      setLoading(true);
      const data = await authApi.getNutriLensProfile("nutrilens");
      setProfile(data);
      setError("");
    } catch (err: any) {
      setError(err.response?.data?.detail || "Failed to load profile");
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const handleSave = async () => {
    if (!profile) return;
    try {
      setSaving(true);
      setSuccess(false);
      const updated = await authApi.updateNutriLensProfile(
        {
          daily_calorie_goal: profile.daily_calorie_goal,
          protein_goal_g: profile.protein_goal_g,
          carbs_goal_g: profile.carbs_goal_g,
          fat_goal_g: profile.fat_goal_g,
          dietary_restrictions: profile.dietary_restrictions,
        },
        "nutrilens"
      );
      setProfile({ ...profile, ...updated });
      setSuccess(true);
      setError("");
    } catch (err: any) {
      setError(err.response?.data?.detail || "Failed to save profile");
    } finally {
      setSaving(false);
    }
  };

  const addRestriction = () => {
    if (restrictionInput.trim() && profile) {
      if (!profile.dietary_restrictions.includes(restrictionInput.trim())) {
        setProfile({
          ...profile,
          dietary_restrictions: [
            ...profile.dietary_restrictions,
            restrictionInput.trim(),
          ],
        });
      }
      setRestrictionInput("");
    }
  };

  const removeRestriction = (restriction: string) => {
    if (profile) {
      setProfile({
        ...profile,
        dietary_restrictions: profile.dietary_restrictions.filter(
          (r) => r !== restriction
        ),
      });
    }
  };

  if (loading) {
    return (
      <Box sx={{ p: 3 }}>
        <Typography>Loading profile...</Typography>
        <LinearProgress />
      </Box>
    );
  }

  if (!profile) {
    return (
      <Box sx={{ p: 3 }}>
        <Alert severity="error">Failed to load profile</Alert>
      </Box>
    );
  }

  return (
    <Box sx={{ p: 3, maxWidth: 600, mx: "auto" }}>
      <Card sx={{ p: 3 }}>
        <Typography variant="h5" sx={{ mb: 3 }}>
          🥗 Nutrition Goals & Preferences
        </Typography>

        {error && (
          <Alert severity="error" sx={{ mb: 2 }}>
            {error}
          </Alert>
        )}

        {success && (
          <Alert severity="success" sx={{ mb: 2 }}>
            Profile updated successfully!
          </Alert>
        )}

        <Stack spacing={2}>
          <TextField
            label="Daily Calorie Goal"
            type="number"
            value={profile.daily_calorie_goal}
            onChange={(e) =>
              setProfile({
                ...profile,
                daily_calorie_goal: parseInt(e.target.value) || 0,
              })
            }
            fullWidth
            helperText="Your daily calorie target (in kcal)"
          />

          <Box sx={{ border: "1px solid #ddd", p: 2, borderRadius: 1 }}>
            <Typography variant="subtitle2" sx={{ mb: 2 }}>
              Daily Macro Goals
            </Typography>
            <Stack spacing={2}>
              <TextField
                label="Protein Goal"
                type="number"
                inputProps={{ step: 0.1 }}
                value={profile.protein_goal_g}
                onChange={(e) =>
                  setProfile({
                    ...profile,
                    protein_goal_g: parseFloat(e.target.value) || 0,
                  })
                }
                fullWidth
                helperText="Grams of protein per day"
              />
              <TextField
                label="Carbs Goal"
                type="number"
                inputProps={{ step: 0.1 }}
                value={profile.carbs_goal_g}
                onChange={(e) =>
                  setProfile({
                    ...profile,
                    carbs_goal_g: parseFloat(e.target.value) || 0,
                  })
                }
                fullWidth
                helperText="Grams of carbohydrates per day"
              />
              <TextField
                label="Fat Goal"
                type="number"
                inputProps={{ step: 0.1 }}
                value={profile.fat_goal_g}
                onChange={(e) =>
                  setProfile({
                    ...profile,
                    fat_goal_g: parseFloat(e.target.value) || 0,
                  })
                }
                fullWidth
                helperText="Grams of fat per day"
              />
            </Stack>
          </Box>

          <Box>
            <Typography variant="subtitle2" sx={{ mb: 1 }}>
              Dietary Restrictions
            </Typography>
            <Box sx={{ display: "flex", gap: 1, mb: 2, flexWrap: "wrap" }}>
              {profile.dietary_restrictions.map((restriction) => (
                <Chip
                  key={restriction}
                  label={restriction}
                  onDelete={() => removeRestriction(restriction)}
                  color="primary"
                  variant="outlined"
                />
              ))}
            </Box>
            <Box sx={{ display: "flex", gap: 1 }}>
              <TextField
                size="small"
                placeholder="Add restriction (e.g., vegetarian)"
                value={restrictionInput}
                onChange={(e) => setRestrictionInput(e.target.value)}
                onKeyPress={(e) => {
                  if (e.key === "Enter") {
                    addRestriction();
                  }
                }}
                sx={{ flex: 1 }}
              />
              <Button
                variant="outlined"
                onClick={addRestriction}
                sx={{ whiteSpace: "nowrap" }}
              >
                Add
              </Button>
            </Box>
            <Typography variant="caption" color="text.secondary">
              e.g., vegetarian, gluten-free, dairy-free, keto, vegan
            </Typography>
          </Box>

          <Box sx={{ display: "flex", gap: 2, pt: 2 }}>
            <Button
              variant="contained"
              onClick={handleSave}
              disabled={saving}
              sx={{ flex: 1 }}
            >
              {saving ? "Saving..." : "Save Changes"}
            </Button>
            <Button
              variant="outlined"
              onClick={loadProfile}
              disabled={saving}
              sx={{ flex: 1 }}
            >
              Reset
            </Button>
          </Box>
        </Stack>
      </Card>
    </Box>
  );
}
