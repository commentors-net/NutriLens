import { useEffect, useState } from "react";
import {
  Alert,
  Box,
  Button,
  Card,
  CardContent,
  CircularProgress,
  Grid,
  Stack,
  TextField,
  Typography,
  LinearProgress,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Paper,
  Chip,
} from "@mui/material";
import RestaurantIcon from "@mui/icons-material/Restaurant";
import LocalFireDepartmentIcon from "@mui/icons-material/LocalFireDepartment";
import FitnessCenterIcon from "@mui/icons-material/FitnessCenter";
import { mealsApi } from "@services/api";
import type { MealTotalResponse, Meal, MealItem } from "@services/api";

export default function NutriLensMeals() {
  const [mealData, setMealData] = useState<MealTotalResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [selectedDate, setSelectedDate] = useState(new Date().toISOString().split("T")[0]);
  const [refreshing, setRefreshing] = useState(false);

  const fetchMeals = async () => {
    setRefreshing(true);
    setError("");
    try {
      const data = await mealsApi.getTodayTotals();
      setMealData(data);
    } catch (err: any) {
      const message = err?.response?.data?.detail || "Failed to load meals";
      setError(String(message));
    } finally {
      setRefreshing(false);
    }
  };

  useEffect(() => {
    setLoading(true);
    fetchMeals();
  }, []);

  const handleDateChange = (newDate: string) => {
    setSelectedDate(newDate);
    fetchMeals();
  };

  const handleRefresh = () => {
    fetchMeals();
  };

  const macroPercentage = (value: number, total: number) => {
    if (total === 0) return 0;
    return Math.round((value / total) * 100);
  };

  if (loading) {
    return (
      <Box sx={{ display: "flex", justifyContent: "center", alignItems: "center", minHeight: "60vh" }}>
        <CircularProgress />
      </Box>
    );
  }

  const totals = mealData || { total_kcal: 0, total_protein_g: 0, total_carbs_g: 0, total_fat_g: 0, meal_count: 0, meals: [] };

  return (
    <Box sx={{ maxWidth: 1200, mx: "auto", mt: { xs: 2, sm: 4 }, px: { xs: 2, sm: 3 }, pb: 4 }}>
      {/* Header */}
      <Box sx={{ mb: 4 }}>
        <Stack direction={{ xs: "column", sm: "row" }} spacing={2} alignItems={{ xs: "flex-start", sm: "center" }} justifyContent="space-between">
          <Box>
            <Typography variant="h5" sx={{ display: "flex", alignItems: "center", gap: 1 }}>
              <RestaurantIcon sx={{ color: "success.main" }} />
              Meal Log
            </Typography>
            <Typography variant="body2" color="text.secondary">
              Track your daily nutrition
            </Typography>
          </Box>
          <Stack direction="row" spacing={2}>
            <TextField
              type="date"
              value={selectedDate}
              onChange={(e) => handleDateChange(e.target.value)}
              size="small"
              sx={{ width: 150 }}
            />
            <Button variant="outlined" onClick={handleRefresh} disabled={refreshing}>
              {refreshing ? "Refreshing..." : "Refresh"}
            </Button>
          </Stack>
        </Stack>
      </Box>

      {error && <Alert severity="error" sx={{ mb: 3 }}>{error}</Alert>}

      {/* Macro Summary Cards */}
      <Grid container spacing={2} sx={{ mb: 4 }}>
        {/* Total Calories */}
        <Grid size={{ xs: 12, sm: 6, md: 3 }}>
          <Card>
            <CardContent>
              <Stack spacing={1}>
                <Stack direction="row" alignItems="center" spacing={1}>
                  <LocalFireDepartmentIcon sx={{ color: "error.main" }} />
                  <Typography variant="subtitle2" color="text.secondary">
                    Calories
                  </Typography>
                </Stack>
                <Typography variant="h4" sx={{ color: "error.main", fontWeight: "bold" }}>
                  {totals.total_kcal}
                </Typography>
                <Typography variant="caption" color="text.secondary">
                  kcal
                </Typography>
              </Stack>
            </CardContent>
          </Card>
        </Grid>

        {/* Protein */}
        <Grid size={{ xs: 12, sm: 6, md: 3 }}>
          <Card>
            <CardContent>
              <Stack spacing={1}>
                <Stack direction="row" alignItems="center" spacing={1}>
                  <FitnessCenterIcon sx={{ color: "primary.main" }} />
                  <Typography variant="subtitle2" color="text.secondary">
                    Protein
                  </Typography>
                </Stack>
                <Typography variant="h4" sx={{ color: "primary.main", fontWeight: "bold" }}>
                  {totals.total_protein_g.toFixed(1)}
                </Typography>
                <Typography variant="caption" color="text.secondary">
                  g ({macroPercentage(totals.total_protein_g * 4, totals.total_kcal)}%)
                </Typography>
              </Stack>
            </CardContent>
          </Card>
        </Grid>

        {/* Carbs */}
        <Grid size={{ xs: 12, sm: 6, md: 3 }}>
          <Card>
            <CardContent>
              <Stack spacing={1}>
                <Typography variant="subtitle2" color="text.secondary">
                  Carbs
                </Typography>
                <Typography variant="h4" sx={{ color: "warning.main", fontWeight: "bold" }}>
                  {totals.total_carbs_g.toFixed(1)}
                </Typography>
                <Typography variant="caption" color="text.secondary">
                  g ({macroPercentage(totals.total_carbs_g * 4, totals.total_kcal)}%)
                </Typography>
              </Stack>
            </CardContent>
          </Card>
        </Grid>

        {/* Fat */}
        <Grid size={{ xs: 12, sm: 6, md: 3 }}>
          <Card>
            <CardContent>
              <Stack spacing={1}>
                <Typography variant="subtitle2" color="text.secondary">
                  Fat
                </Typography>
                <Typography variant="h4" sx={{ color: "info.main", fontWeight: "bold" }}>
                  {totals.total_fat_g.toFixed(1)}
                </Typography>
                <Typography variant="caption" color="text.secondary">
                  g ({macroPercentage(totals.total_fat_g * 9, totals.total_kcal)}%)
                </Typography>
              </Stack>
            </CardContent>
          </Card>
        </Grid>
      </Grid>

      {/* Macro Breakdown Bar */}
      {totals.total_kcal > 0 && (
        <Card sx={{ mb: 4 }}>
          <CardContent>
            <Typography variant="subtitle2" sx={{ mb: 2 }}>
              Macro Breakdown
            </Typography>
            <Stack spacing={1}>
              <Box>
                <Stack direction="row" justifyContent="space-between" sx={{ mb: 0.5 }}>
                  <Typography variant="caption">Protein</Typography>
                  <Typography variant="caption" sx={{ fontWeight: "bold" }}>
                    {macroPercentage(totals.total_protein_g * 4, totals.total_kcal)}%
                  </Typography>
                </Stack>
                <LinearProgress
                  variant="determinate"
                  value={macroPercentage(totals.total_protein_g * 4, totals.total_kcal)}
                  sx={{ bgcolor: "primary.light", "& .MuiLinearProgress-bar": { bgcolor: "primary.main" } }}
                />
              </Box>
              <Box>
                <Stack direction="row" justifyContent="space-between" sx={{ mb: 0.5 }}>
                  <Typography variant="caption">Carbs</Typography>
                  <Typography variant="caption" sx={{ fontWeight: "bold" }}>
                    {macroPercentage(totals.total_carbs_g * 4, totals.total_kcal)}%
                  </Typography>
                </Stack>
                <LinearProgress
                  variant="determinate"
                  value={macroPercentage(totals.total_carbs_g * 4, totals.total_kcal)}
                  sx={{ bgcolor: "warning.light", "& .MuiLinearProgress-bar": { bgcolor: "warning.main" } }}
                />
              </Box>
              <Box>
                <Stack direction="row" justifyContent="space-between" sx={{ mb: 0.5 }}>
                  <Typography variant="caption">Fat</Typography>
                  <Typography variant="caption" sx={{ fontWeight: "bold" }}>
                    {macroPercentage(totals.total_fat_g * 9, totals.total_kcal)}%
                  </Typography>
                </Stack>
                <LinearProgress
                  variant="determinate"
                  value={macroPercentage(totals.total_fat_g * 9, totals.total_kcal)}
                  sx={{ bgcolor: "info.light", "& .MuiLinearProgress-bar": { bgcolor: "info.main" } }}
                />
              </Box>
            </Stack>
          </CardContent>
        </Card>
      )}

      {/* Meals List */}
      {totals.meals.length === 0 ? (
        <Card>
          <CardContent>
            <Typography color="text.secondary" align="center" sx={{ py: 3 }}>
              No meals logged for {selectedDate}
            </Typography>
          </CardContent>
        </Card>
      ) : (
        <Stack spacing={2}>
          {totals.meals.map((meal: Meal, idx: number) => (
            <Card key={meal.meal_id || idx} variant="outlined">
              <CardContent>
                <Stack spacing={2}>
                  {/* Meal Header */}
                  <Box>
                    <Stack direction={{ xs: "column", sm: "row" }} justifyContent="space-between" alignItems={{ xs: "flex-start", sm: "center" }}>
                      <Box>
                        <Typography variant="subtitle1" sx={{ fontWeight: 600 }}>
                          {new Date(meal.timestamp).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })}
                        </Typography>
                        {meal.notes && (
                          <Typography variant="body2" color="text.secondary">
                            {meal.notes}
                          </Typography>
                        )}
                      </Box>
                      <Chip
                        icon={<LocalFireDepartmentIcon />}
                        label={`${meal.total_kcal} kcal`}
                        color="error"
                        variant="filled"
                      />
                    </Stack>
                  </Box>

                  {/* Items Table */}
                  {meal.items && meal.items.length > 0 && (
                    <TableContainer component={Paper} variant="outlined">
                      <Table size="small">
                        <TableHead>
                          <TableRow sx={{ bgcolor: "background.default" }}>
                            <TableCell>Food Item</TableCell>
                            <TableCell align="right">Grams</TableCell>
                            <TableCell align="right">Kcal</TableCell>
                            <TableCell align="right">Protein</TableCell>
                            <TableCell align="right">Carbs</TableCell>
                            <TableCell align="right">Fat</TableCell>
                          </TableRow>
                        </TableHead>
                        <TableBody>
                          {meal.items.map((item: MealItem, itemIdx: number) => (
                            <TableRow key={itemIdx}>
                              <TableCell>{item.label}</TableCell>
                              <TableCell align="right">{item.grams}g</TableCell>
                              <TableCell align="right" sx={{ fontWeight: 600 }}>
                                {item.kcal}
                              </TableCell>
                              <TableCell align="right">{item.protein_g.toFixed(1)}g</TableCell>
                              <TableCell align="right">{item.carbs_g.toFixed(1)}g</TableCell>
                              <TableCell align="right">{item.fat_g.toFixed(1)}g</TableCell>
                            </TableRow>
                          ))}
                        </TableBody>
                      </Table>
                    </TableContainer>
                  )}
                </Stack>
              </CardContent>
            </Card>
          ))}
        </Stack>
      )}
    </Box>
  );
}
