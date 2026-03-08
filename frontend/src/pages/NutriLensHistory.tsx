import { useEffect, useState, useMemo } from "react";
import {
  Alert,
  Box,
  Button,
  Card,
  CardContent,
  CircularProgress,
  Stack,
  TextField,
  Typography,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Chip,
  Divider,
} from "@mui/material";
import HistoryIcon from "@mui/icons-material/History";
import CalendarTodayIcon from "@mui/icons-material/CalendarToday";
import LocalFireDepartmentIcon from "@mui/icons-material/LocalFireDepartment";
import TrendingUpIcon from "@mui/icons-material/TrendingUp";
import ShowChartIcon from "@mui/icons-material/ShowChart";
import PieChartIcon from "@mui/icons-material/PieChart";
import {
  LineChart,
  Line,
  BarChart,
  Bar,
  PieChart,
  Pie,
  Cell,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer,
} from "recharts";
import { mealsApi } from "@services/api";
import type { MealTotalResponse } from "@services/api";

export default function NutriLensHistory() {
  const [mealData, setMealData] = useState<MealTotalResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  
  // Default to last 30 days
  const today = new Date();
  const thirtyDaysAgo = new Date(today);
  thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
  
  const [startDate, setStartDate] = useState(thirtyDaysAgo.toISOString().split("T")[0]);
  const [endDate, setEndDate] = useState(today.toISOString().split("T")[0]);
  const [refreshing, setRefreshing] = useState(false);

  const fetchMeals = async (start: string, end: string) => {
    setRefreshing(true);
    setError("");
    try {
      const data = await mealsApi.getMealsByRange(start, end);
      setMealData(data);
    } catch (err: any) {
      const message = err?.response?.data?.detail || "Failed to load meal history";
      setError(String(message));
    } finally {
      setRefreshing(false);
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchMeals(startDate, endDate);
  }, []);

  const handleApplyDateRange = () => {
    fetchMeals(startDate, endDate);
  };

  const handleQuickRange = (days: number) => {
    const end = new Date();
    const start = new Date(end);
    start.setDate(start.getDate() - days);
    setStartDate(start.toISOString().split("T")[0]);
    setEndDate(end.toISOString().split("T")[0]);
    fetchMeals(start.toISOString().split("T")[0], end.toISOString().split("T")[0]);
  };

  // Group meals by date
  const groupedMeals = (mealData?.meals || []).reduce((acc: any, meal: any) => {
    const dateStr = meal.timestamp.split("T")[0];
    if (!acc[dateStr]) {
      acc[dateStr] = [];
    }
    acc[dateStr].push(meal);
    return acc;
  }, {});

  const totals = mealData || { total_kcal: 0, total_protein_g: 0, total_carbs_g: 0, total_fat_g: 0, meal_count: 0, meals: [] };

  // Prepare chart data - aggregate meals by date with macros
  const chartData = useMemo(() => {
    const dailyData: { [key: string]: { date: string; kcal: number; protein: number; carbs: number; fat: number } } = {};
    
    // First, create entries for all dates in range (to show empty days)
    const start = new Date(startDate);
    const end = new Date(endDate);
    for (let d = new Date(start); d <= end; d.setDate(d.getDate() + 1)) {
      const dateStr = d.toISOString().split("T")[0];
      dailyData[dateStr] = { date: dateStr, kcal: 0, protein: 0, carbs: 0, fat: 0 };
    }
    
    // Then aggregate meal data
    (mealData?.meals || []).forEach((meal: any) => {
      const dateStr = meal.timestamp.split("T")[0];
      if (dailyData[dateStr]) {
        dailyData[dateStr].kcal += meal.total_kcal || 0;
        // Note: Individual meal summaries don't have macro breakdown in current schema
        // We'll need to enhance the API response or calculate from items
      }
    });
    
    return Object.values(dailyData).sort((a, b) => a.date.localeCompare(b.date));
  }, [mealData, startDate, endDate]);

  // Prepare pie chart data for macro distribution
  const macroDistribution = useMemo(() => {
    const protein = totals.total_protein_g;
    const carbs = totals.total_carbs_g;
    const fat = totals.total_fat_g;
    
    // Calculate calories from macros (protein: 4 kcal/g, carbs: 4 kcal/g, fat: 9 kcal/g)
    const proteinKcal = protein * 4;
    const carbsKcal = carbs * 4;
    const fatKcal = fat * 9;
    
    return [
      { name: "Protein", value: proteinKcal, grams: protein, color: "#4caf50" },
      { name: "Carbs", value: carbsKcal, grams: carbs, color: "#2196f3" },
      { name: "Fat", value: fatKcal, grams: fat, color: "#ff9800" },
    ];
  }, [totals]);

  const CHART_COLORS = {
    protein: "#4caf50",
    carbs: "#2196f3",
    fat: "#ff9800",
    kcal: "#f44336",
  };

  if (loading) {
    return (
      <Box sx={{ display: "flex", justifyContent: "center", alignItems: "center", minHeight: "60vh" }}>
        <CircularProgress />
      </Box>
    );
  }

  return (
    <Box sx={{ maxWidth: 1200, mx: "auto", mt: { xs: 2, sm: 4 }, px: { xs: 2, sm: 3 }, pb: 4 }}>
      {/* Header */}
      <Stack direction="row" alignItems="center" spacing={2} sx={{ mb: 3 }}>
        <HistoryIcon sx={{ fontSize: 32, color: "primary.main" }} />
        <Typography variant="h4" component="h1" fontWeight="bold">
          Meal History
        </Typography>
      </Stack>

      {error && (
        <Alert severity="error" sx={{ mb: 3 }} onClose={() => setError("")}>
          {error}
        </Alert>
      )}

      {/* Date Range Selector */}
      <Card sx={{ mb: 3 }}>
        <CardContent>
          <Stack direction={{ xs: "column", sm: "row" }} spacing={2} alignItems="center">
            <CalendarTodayIcon sx={{ color: "text.secondary" }} />
            <TextField
              label="Start Date"
              type="date"
              value={startDate}
              onChange={(e) => setStartDate(e.target.value)}
              InputLabelProps={{ shrink: true }}
              size="small"
            />
            <Typography>to</Typography>
            <TextField
              label="End Date"
              type="date"
              value={endDate}
              onChange={(e) => setEndDate(e.target.value)}
              InputLabelProps={{ shrink: true }}
              size="small"
            />
            <Button
              variant="contained"
              onClick={handleApplyDateRange}
              disabled={refreshing}
            >
              Apply
            </Button>
          </Stack>

          {/* Quick Range Buttons */}
          <Stack direction="row" spacing={1} sx={{ mt: 2 }}>
            <Chip label="Last 7 days" onClick={() => handleQuickRange(7)} clickable />
            <Chip label="Last 30 days" onClick={() => handleQuickRange(30)} clickable />
            <Chip label="Last 90 days" onClick={() => handleQuickRange(90)} clickable />
          </Stack>
        </CardContent>
      </Card>

      {/* Summary Stats */}
      <Stack direction={{ xs: "column", sm: "row" }} spacing={2} sx={{ mb: 3 }}>
        <Card sx={{ flex: 1 }}>
          <CardContent>
            <Stack direction="row" alignItems="center" spacing={1}>
              <LocalFireDepartmentIcon color="error" />
              <Typography variant="body2" color="text.secondary">
                Total Calories
              </Typography>
            </Stack>
            <Typography variant="h4" fontWeight="bold" sx={{ mt: 1 }}>
              {totals.total_kcal.toLocaleString()}
            </Typography>
            <Typography variant="caption" color="text.secondary">
              kcal
            </Typography>
          </CardContent>
        </Card>
        
        <Card sx={{ flex: 1 }}>
          <CardContent>
            <Typography variant="body2" color="text.secondary">
              Total Protein
            </Typography>
            <Typography variant="h4" fontWeight="bold" sx={{ mt: 1 }}>
              {totals.total_protein_g}
            </Typography>
            <Typography variant="caption" color="text.secondary">
              g
            </Typography>
          </CardContent>
        </Card>

        <Card sx={{ flex: 1 }}>
          <CardContent>
            <Typography variant="body2" color="text.secondary">
              Total Carbs
            </Typography>
            <Typography variant="h4" fontWeight="bold" sx={{ mt: 1 }}>
              {totals.total_carbs_g}
            </Typography>
            <Typography variant="caption" color="text.secondary">
              g
            </Typography>
          </CardContent>
        </Card>

        <Card sx={{ flex: 1 }}>
          <CardContent>
            <Typography variant="body2" color="text.secondary">
              Total Fat
            </Typography>
            <Typography variant="h4" fontWeight="bold" sx={{ mt: 1 }}>
              {totals.total_fat_g}
            </Typography>
            <Typography variant="caption" color="text.secondary">
              g
            </Typography>
          </CardContent>
        </Card>
      </Stack>

      {/* Visualization Charts */}
      {totals.meal_count > 0 && (
        <>
          {/* Daily Calorie Trend Line Chart */}
          <Card sx={{ mb: 3 }}>
            <CardContent>
              <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 2 }}>
                <ShowChartIcon color="primary" />
                <Typography variant="h6" fontWeight="bold">
                  Daily Calorie Trend
                </Typography>
              </Stack>
              <ResponsiveContainer width="100%" height={300}>
                <LineChart data={chartData}>
                  <CartesianGrid strokeDasharray="3 3" />
                  <XAxis
                    dataKey="date"
                    tickFormatter={(value) => {
                      const date = new Date(value);
                      return `${date.getMonth() + 1}/${date.getDate()}`;
                    }}
                  />
                  <YAxis />
                  <Tooltip
                    labelFormatter={(value) => {
                      const date = new Date(value as string);
                      return date.toLocaleDateString("en-US", {
                        month: "short",
                        day: "numeric",
                        year: "numeric",
                      });
                    }}
                  />
                  <Legend />
                  <Line
                    type="monotone"
                    dataKey="kcal"
                    stroke={CHART_COLORS.kcal}
                    strokeWidth={2}
                    name="Calories"
                    dot={{ r: 4 }}
                    activeDot={{ r: 6 }}
                  />
                </LineChart>
              </ResponsiveContainer>
            </CardContent>
          </Card>

          {/* Two-column layout for remaining charts */}
          <Stack direction={{ xs: "column", md: "row" }} spacing={3} sx={{ mb: 3 }}>
            {/* Macro Distribution Pie Chart */}
            <Card sx={{ flex: 1 }}>
              <CardContent>
                <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 2 }}>
                  <PieChartIcon color="primary" />
                  <Typography variant="h6" fontWeight="bold">
                    Macro Distribution
                  </Typography>
                </Stack>
                <ResponsiveContainer width="100%" height={300}>
                  <PieChart>
                    <Pie
                      data={macroDistribution}
                      cx="50%"
                      cy="50%"
                      labelLine={false}
                      label={(entry: any) => `${entry.name}: ${entry.grams.toFixed(0)}g`}
                      outerRadius={80}
                      fill="#8884d8"
                      dataKey="value"
                    >
                      {macroDistribution.map((entry, index) => (
                        <Cell key={`cell-${index}`} fill={entry.color} />
                      ))}
                    </Pie>
                    <Tooltip
                      formatter={(value: any, name: any, props: any) => [
                        `${(value as number).toFixed(0)} kcal (${props.payload.grams.toFixed(0)}g)`,
                        name,
                      ]}
                    />
                    <Legend />
                  </PieChart>
                </ResponsiveContainer>
              </CardContent>
            </Card>

            {/* Macro Breakdown Bar Chart */}
            <Card sx={{ flex: 1 }}>
              <CardContent>
                <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 2 }}>
                  <TrendingUpIcon color="primary" />
                  <Typography variant="h6" fontWeight="bold">
                    Total Macros (grams)
                  </Typography>
                </Stack>
                <ResponsiveContainer width="100%" height={300}>
                  <BarChart
                    data={[
                      {
                        name: "Macros",
                        Protein: totals.total_protein_g,
                        Carbs: totals.total_carbs_g,
                        Fat: totals.total_fat_g,
                      },
                    ]}
                  >
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis dataKey="name" />
                    <YAxis />
                    <Tooltip />
                    <Legend />
                    <Bar dataKey="Protein" fill={CHART_COLORS.protein} />
                    <Bar dataKey="Carbs" fill={CHART_COLORS.carbs} />
                    <Bar dataKey="Fat" fill={CHART_COLORS.fat} />
                  </BarChart>
                </ResponsiveContainer>
              </CardContent>
            </Card>
          </Stack>
        </>
      )}

      {/* Meals Grouped by Date */}
      {totals.meal_count === 0 ? (
        <Card>
          <CardContent>
            <Typography align="center" color="text.secondary">
              No meals found in this date range. Start logging meals to see them here!
            </Typography>
          </CardContent>
        </Card>
      ) : (
        Object.entries(groupedMeals)
          .sort(([dateA], [dateB]) => dateB.localeCompare(dateA))
          .map(([date, meals]: [string, any]) => (
            <Card key={date} sx={{ mb: 2 }}>
              <CardContent>
                <Typography variant="h6" fontWeight="bold" sx={{ mb: 2 }}>
                  {new Date(date).toLocaleDateString("en-US", {
                    weekday: "long",
                    month: "long",
                    day: "numeric",
                    year: "numeric",
                  })}
                </Typography>
                <Divider sx={{ mb: 2 }} />
                <TableContainer>
                  <Table size="small">
                    <TableHead>
                      <TableRow>
                        <TableCell>Time</TableCell>
                        <TableCell>Meal ID</TableCell>
                        <TableCell align="right">Items</TableCell>
                        <TableCell align="right">Calories</TableCell>
                      </TableRow>
                    </TableHead>
                    <TableBody>
                      {meals.map((meal: any) => (
                        <TableRow key={meal.meal_id} hover>
                          <TableCell>
                            {new Date(meal.timestamp).toLocaleTimeString("en-US", {
                              hour: "2-digit",
                              minute: "2-digit",
                            })}
                          </TableCell>
                          <TableCell>
                            <Typography variant="body2" sx={{ fontFamily: "monospace", fontSize: "0.75rem" }}>
                              {meal.meal_id.substring(0, 8)}...
                            </Typography>
                          </TableCell>
                          <TableCell align="right">{meal.item_count}</TableCell>
                          <TableCell align="right">
                            <Chip
                              label={`${meal.total_kcal} kcal`}
                              size="small"
                              color="primary"
                              variant="outlined"
                            />
                          </TableCell>
                        </TableRow>
                      ))}
                    </TableBody>
                  </Table>
                </TableContainer>
              </CardContent>
            </Card>
          ))
      )}
    </Box>
  );
}
