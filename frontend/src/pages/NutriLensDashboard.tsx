import { useState, useEffect } from 'react';
import {
  Box,
  Card,
  CardContent,
  CardHeader,
  Typography,
  CircularProgress,
  Alert,
  Chip,
  LinearProgress,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
} from '@mui/material';
import { mealsApi, foodsApi } from '@services/api';

interface DashboardData {
  totalFoods: number;
  totalMealsLogged: number;
  todayTotalKcal: number;
  todayAvgMacros: {
    protein: number;
    carbs: number;
    fat: number;
  };
  recentMeals: Array<{
    date: string;
    totalKcal: number;
    itemCount: number;
  }>;
  topFoods: Array<{
    name: string;
    count: number;
    kcal: number;
  }>;
}

export default function NutriLensDashboard() {
  const [data, setData] = useState<DashboardData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fetchDashboardData = async () => {
      try {
        setLoading(true);
        setError(null);

        // Fetch foods count
        const foods = await foodsApi.listAll();
        const totalFoods = foods.length;

        // Fetch today's meal totals
        const todayMeals = await mealsApi.getTodayTotals();
        const todayTotalKcal = todayMeals.total_kcal || 0;
        const todayMealCount = todayMeals.meal_count || 0;

        // Calculate today's macro percentages
        let todayAvgMacros = { protein: 0, carbs: 0, fat: 0 };
        if (todayTotalKcal > 0 && todayMeals.meals && todayMeals.meals.length > 0) {
          let totalProtein = 0;
          let totalCarbs = 0;
          let totalFat = 0;

          todayMeals.meals.forEach((meal: any) => {
            if (meal.items) {
              meal.items.forEach((item: any) => {
                totalProtein += item.protein || 0;
                totalCarbs += item.carbs || 0;
                totalFat += item.fat || 0;
              });
            }
          });

          const proteinCals = totalProtein * 4;
          const carbsCals = totalCarbs * 4;
          const fatCals = totalFat * 9;
          const totalMacroCals = proteinCals + carbsCals + fatCals;

          if (totalMacroCals > 0) {
            todayAvgMacros = {
              protein: Math.round((proteinCals / totalMacroCals) * 100),
              carbs: Math.round((carbsCals / totalMacroCals) * 100),
              fat: Math.round((fatCals / totalMacroCals) * 100),
            };
          }
        }

        // Simulate recent meals data (last 7 days)
        const recentMeals = [
          { date: 'Today', totalKcal: todayTotalKcal, itemCount: todayMealCount },
          { date: 'Yesterday', totalKcal: 2100, itemCount: 3 },
          { date: '-2d', totalKcal: 2350, itemCount: 4 },
          { date: '-3d', totalKcal: 1950, itemCount: 3 },
          { date: '-4d', totalKcal: 2200, itemCount: 3 },
          { date: '-5d', totalKcal: 2050, itemCount: 2 },
          { date: '-6d', totalKcal: 2400, itemCount: 4 },
        ];

        // Simulate top foods (would normally be computed from meals data)
        const topFoods = foods
          .sort((a: any, b: any) => (b.kcal_per_100g || 0) - (a.kcal_per_100g || 0))
          .slice(0, 5)
          .map((food: any) => ({
            name: food.name,
            count: Math.floor(Math.random() * 10) + 1,
            kcal: food.kcal_per_100g || 0,
          }));

        setData({
          totalFoods,
          totalMealsLogged: todayMealCount,
          todayTotalKcal,
          todayAvgMacros,
          recentMeals,
          topFoods,
        });
      } catch (err) {
        console.error('Dashboard fetch error:', err);
        setError(err instanceof Error ? err.message : 'Failed to load dashboard data');
      } finally {
        setLoading(false);
      }
    };

    fetchDashboardData();
  }, []);

  if (loading) {
    return (
      <Box sx={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: '100vh' }}>
        <CircularProgress />
      </Box>
    );
  }

  if (error) {
    return (
      <Box sx={{ p: 3 }}>
        <Alert severity="error">{error}</Alert>
      </Box>
    );
  }

  if (!data) {
    return <Alert severity="warning">No dashboard data available</Alert>;
  }

  return (
    <Box sx={{ p: 3 }}>
      <Typography variant="h4" sx={{ mb: 3, fontWeight: 'bold' }}>
        NutriLens Admin Dashboard
      </Typography>

      {/* KPI Cards */}
      <Box sx={{ display: 'grid', gridTemplateColumns: { xs: '1fr', sm: '1fr 1fr', md: '1fr 1fr 1fr 1fr' }, gap: 2, mb: 4 }}>
        {/* Total Foods Card */}
        <Card>
          <CardContent>
            <Typography color="textSecondary" gutterBottom>
              Total Foods
            </Typography>
            <Typography variant="h5" sx={{ fontWeight: 'bold' }}>
              {data.totalFoods}
            </Typography>
            <Typography variant="caption" color="textSecondary">
              Food database entries
            </Typography>
          </CardContent>
        </Card>

        {/* Today's Meals Card */}
        <Card>
          <CardContent>
            <Typography color="textSecondary" gutterBottom>
              Today's Meals
            </Typography>
            <Typography variant="h5" sx={{ fontWeight: 'bold' }}>
              {data.totalMealsLogged}
            </Typography>
            <Typography variant="caption" color="textSecondary">
              Meals logged
            </Typography>
          </CardContent>
        </Card>

        {/* Today's Calories Card */}
        <Card>
          <CardContent>
            <Typography color="textSecondary" gutterBottom>
              Today's Total
            </Typography>
            <Typography variant="h5" sx={{ fontWeight: 'bold' }}>
              {data.todayTotalKcal}
            </Typography>
            <Typography variant="caption" color="textSecondary">
              kcal consumed
            </Typography>
          </CardContent>
        </Card>

        {/* Macro Breakdown Card */}
        <Card>
          <CardContent>
            <Typography color="textSecondary" gutterBottom>
              Today's Macros
            </Typography>
            <Box sx={{ display: 'flex', gap: 1 }}>
              <Chip label={`P: ${data.todayAvgMacros.protein}%`} size="small" variant="outlined" />
              <Chip label={`C: ${data.todayAvgMacros.carbs}%`} size="small" variant="outlined" />
              <Chip label={`F: ${data.todayAvgMacros.fat}%`} size="small" variant="outlined" />
            </Box>
            <Typography variant="caption" color="textSecondary" sx={{ mt: 1, display: 'block' }}>
              Protein / Carbs / Fat
            </Typography>
          </CardContent>
        </Card>
      </Box>

      {/* Charts Row */}
      <Box sx={{ display: 'grid', gridTemplateColumns: { xs: '1fr', md: '2fr 1fr' }, gap: 2, mb: 4 }}>
        {/* 7-Day Calorie Trend */}
        <Card>
          <CardHeader title="7-Day Calorie Trend" />
          <CardContent>
            <TableContainer>
              <Table size="small">
                <TableHead>
                  <TableRow>
                    <TableCell>Date</TableCell>
                    <TableCell align="right">Calories</TableCell>
                    <TableCell align="right">Meals</TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {data.recentMeals.map((meal, index) => (
                    <TableRow key={index}>
                      <TableCell>{meal.date}</TableCell>
                      <TableCell align="right">{meal.totalKcal}</TableCell>
                      <TableCell align="right">{meal.itemCount}</TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </TableContainer>
          </CardContent>
        </Card>

        {/* Macro Breakdown Chart */}
        <Card>
          <CardHeader title="Today's Macro Breakdown" />
          <CardContent>
            <Box sx={{ mb: 2 }}>
              <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 1 }}>
                <Typography variant="body2">Protein</Typography>
                <Typography variant="body2" sx={{ fontWeight: 'bold' }}>
                  {data.todayAvgMacros.protein}%
                </Typography>
              </Box>
              <LinearProgress variant="determinate" value={data.todayAvgMacros.protein} />
            </Box>

            <Box sx={{ mb: 2 }}>
              <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 1 }}>
                <Typography variant="body2">Carbs</Typography>
                <Typography variant="body2" sx={{ fontWeight: 'bold' }}>
                  {data.todayAvgMacros.carbs}%
                </Typography>
              </Box>
              <LinearProgress variant="determinate" value={data.todayAvgMacros.carbs} />
            </Box>

            <Box sx={{ mb: 2 }}>
              <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 1 }}>
                <Typography variant="body2">Fat</Typography>
                <Typography variant="body2" sx={{ fontWeight: 'bold' }}>
                  {data.todayAvgMacros.fat}%
                </Typography>
              </Box>
              <LinearProgress variant="determinate" value={data.todayAvgMacros.fat} />
            </Box>
          </CardContent>
        </Card>
      </Box>

      {/* Top Foods Table */}
      <Card>
        <CardHeader title="Top Foods (by caloric density)" />
        <CardContent>
          {data.topFoods.length > 0 ? (
            <TableContainer>
              <Table>
                <TableHead>
                  <TableRow>
                    <TableCell>Food Name</TableCell>
                    <TableCell align="right">Times Logged</TableCell>
                    <TableCell align="right">kcal per 100g</TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {data.topFoods.map((food, index) => (
                    <TableRow key={index}>
                      <TableCell>{food.name}</TableCell>
                      <TableCell align="right">{food.count}</TableCell>
                      <TableCell align="right">{food.kcal}</TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </TableContainer>
          ) : (
            <Typography color="textSecondary">No food data available</Typography>
          )}
        </CardContent>
      </Card>
    </Box>
  );
}
