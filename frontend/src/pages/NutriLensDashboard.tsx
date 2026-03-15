import { useState, useEffect } from 'react';
import {
  Box,
  Button,
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
import DownloadIcon from '@mui/icons-material/Download';
import { mealsApi, foodsApi, authApi } from '@services/api';
import type { CorrectionsAnalyticsResponse } from '@services/api';

interface GoalProgress {
  calories: number;
  protein: number;
  carbs: number;
  fat: number;
}

interface NutriLensProfile {
  username: string;
  daily_calorie_goal: number;
  protein_goal_g: number;
  carbs_goal_g: number;
  fat_goal_g: number;
  dietary_restrictions: string[];
}

interface DashboardData {
  totalFoods: number;
  totalMealsLogged: number;
  todayTotalKcal: number;
  todayTotalProtein: number;
  todayTotalCarbs: number;
  todayTotalFat: number;
  todayAvgMacros: {
    protein: number;
    carbs: number;
    fat: number;
  };
  profile: NutriLensProfile;
  goalProgress: GoalProgress;
  recentMeals: Array<{
    date: string;
    totalKcal: number;
    mealCount: number;
  }>;
  topFoods: Array<{
    name: string;
    count: number;
    totalKcal: number;
  }>;
  correctionsAnalytics: CorrectionsAnalyticsResponse;
}

export default function NutriLensDashboard() {
  const [data, setData] = useState<DashboardData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [exportingFormat, setExportingFormat] = useState<'csv' | 'pdf' | null>(null);
  const [updatingFeedbackRules, setUpdatingFeedbackRules] = useState(false);

  const handleExportToday = async (format: 'csv' | 'pdf') => {
    try {
      setExportingFormat(format);
      const today = new Date().toISOString().split('T')[0];
      const blob = await mealsApi.exportMeals(today, today, format);
      const url = window.URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = url;
      link.download = `nutrilens_today.${format}`;
      document.body.appendChild(link);
      link.click();
      link.remove();
      window.URL.revokeObjectURL(url);
    } catch (err) {
      console.error('Dashboard export failed:', err);
      setError(err instanceof Error ? err.message : 'Failed to export today\'s meals');
    } finally {
      setExportingFormat(null);
    }
  };

  const handleToggleFeedbackRules = async () => {
    if (!data?.correctionsAnalytics.feedback_rules) {
      return;
    }

    const targetEnabled = !data.correctionsAnalytics.feedback_rules.enabled;

    try {
      setUpdatingFeedbackRules(true);
      setError(null);
      const response = await mealsApi.updateFeedbackRulesEnabled(targetEnabled);
      const refreshedAnalytics = await mealsApi.getCorrectionsAnalytics(
        data.correctionsAnalytics.window.start ?? undefined,
        data.correctionsAnalytics.window.end ?? undefined,
        data.correctionsAnalytics.window.limit || 1000,
      );

      setData((prev) => {
        if (!prev) {
          return prev;
        }

        return {
          ...prev,
          correctionsAnalytics: {
            ...refreshedAnalytics,
            feedback_rules: response.feedback_rules,
          },
        };
      });
    } catch (err) {
      console.error('Feedback-rules update failed:', err);
      setError(err instanceof Error ? err.message : 'Failed to update feedback auto-adjust setting');
    } finally {
      setUpdatingFeedbackRules(false);
    }
  };

  useEffect(() => {
    const fetchDashboardData = async () => {
      try {
        setLoading(true);
        setError(null);

        const today = new Date();
        const startDate = new Date(today);
        startDate.setDate(startDate.getDate() - 6);
        const analyticsStartDate = new Date(today);
        analyticsStartDate.setDate(analyticsStartDate.getDate() - 29);
        const todayStr = today.toISOString().split('T')[0];
        const startDateStr = startDate.toISOString().split('T')[0];
        const analyticsStartDateStr = analyticsStartDate.toISOString().split('T')[0];

        // Fetch foods count
        const foods = await foodsApi.listAll();
        const totalFoods = foods.length;

        // Fetch today's meal totals
        const todayMeals = await mealsApi.getTodayTotals();
        const recentRangeMeals = await mealsApi.getMealsByRange(startDateStr, todayStr);
        const correctionsAnalytics = await mealsApi.getCorrectionsAnalytics(
          analyticsStartDateStr,
          todayStr,
          1000,
        );
        const todayTotalKcal = todayMeals.total_kcal || 0;
        const todayMealCount = todayMeals.meal_count || 0;
        const todayTotalProtein = todayMeals.total_protein_g || 0;
        const todayTotalCarbs = todayMeals.total_carbs_g || 0;
        const todayTotalFat = todayMeals.total_fat_g || 0;

        // Fetch profile goals
        const profile = await authApi.getNutriLensProfile('nutrilens');

        // Calculate today's macro percentages
        let todayAvgMacros = { protein: 0, carbs: 0, fat: 0 };
        if (todayTotalKcal > 0) {
          const proteinCals = todayTotalProtein * 4;
          const carbsCals = todayTotalCarbs * 4;
          const fatCals = todayTotalFat * 9;
          const totalMacroCals = proteinCals + carbsCals + fatCals;

          if (totalMacroCals > 0) {
            todayAvgMacros = {
              protein: Math.round((proteinCals / totalMacroCals) * 100),
              carbs: Math.round((carbsCals / totalMacroCals) * 100),
              fat: Math.round((fatCals / totalMacroCals) * 100),
            };
          }
        }

        const goalProgress: GoalProgress = {
          calories:
            profile.daily_calorie_goal > 0
              ? Math.min(Math.round((todayTotalKcal / profile.daily_calorie_goal) * 100), 100)
              : 0,
          protein:
            profile.protein_goal_g > 0
              ? Math.min(Math.round((todayTotalProtein / profile.protein_goal_g) * 100), 100)
              : 0,
          carbs:
            profile.carbs_goal_g > 0
              ? Math.min(Math.round((todayTotalCarbs / profile.carbs_goal_g) * 100), 100)
              : 0,
          fat:
            profile.fat_goal_g > 0
              ? Math.min(Math.round((todayTotalFat / profile.fat_goal_g) * 100), 100)
              : 0,
        };

        const recentMealsMap = new Map<string, { date: string; totalKcal: number; mealCount: number }>();
        for (let offset = 0; offset < 7; offset += 1) {
          const bucketDate = new Date(startDate);
          bucketDate.setDate(startDate.getDate() + offset);
          const dateKey = bucketDate.toISOString().split('T')[0];
          recentMealsMap.set(dateKey, { date: dateKey, totalKcal: 0, mealCount: 0 });
        }

        const topFoodsMap = new Map<string, { name: string; count: number; totalKcal: number }>();
        (recentRangeMeals.meals || []).forEach((meal: any) => {
          const dateKey = String(meal.timestamp || '').split('T')[0];
          const dayBucket = recentMealsMap.get(dateKey);
          if (dayBucket) {
            dayBucket.totalKcal += meal.total_kcal || 0;
            dayBucket.mealCount += 1;
          }

          (meal.items || []).forEach((item: any) => {
            const label = item.label || 'Unknown';
            const existing = topFoodsMap.get(label) || { name: label, count: 0, totalKcal: 0 };
            existing.count += 1;
            existing.totalKcal += item.kcal || 0;
            topFoodsMap.set(label, existing);
          });
        });

        const recentMeals = Array.from(recentMealsMap.values()).sort((a, b) => a.date.localeCompare(b.date));
        const topFoods = Array.from(topFoodsMap.values())
          .sort((a, b) => {
            if (b.count !== a.count) {
              return b.count - a.count;
            }
            return b.totalKcal - a.totalKcal;
          })
          .slice(0, 5);

        setData({
          totalFoods,
          totalMealsLogged: todayMealCount,
          todayTotalKcal,
          todayTotalProtein,
          todayTotalCarbs,
          todayTotalFat,
          todayAvgMacros,
          profile,
          goalProgress,
          recentMeals,
          topFoods,
          correctionsAnalytics,
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

      <Box sx={{ display: 'flex', gap: 2, mb: 3, flexWrap: 'wrap' }}>
        <Button
          variant="outlined"
          startIcon={<DownloadIcon />}
          onClick={() => handleExportToday('csv')}
          disabled={!!exportingFormat}
        >
          {exportingFormat === 'csv' ? 'Exporting CSV...' : 'Export Today CSV'}
        </Button>
        <Button
          variant="outlined"
          startIcon={<DownloadIcon />}
          onClick={() => handleExportToday('pdf')}
          disabled={!!exportingFormat}
        >
          {exportingFormat === 'pdf' ? 'Exporting PDF...' : 'Export Today PDF'}
        </Button>
      </Box>

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

      {/* Daily Goal Progress */}
      <Card sx={{ mb: 4 }}>
        <CardHeader title="Daily Goal Progress" />
        <CardContent>
          <Box sx={{ mb: 2 }}>
            <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 1 }}>
              <Typography variant="body2">Calories ({data.todayTotalKcal} / {data.profile.daily_calorie_goal} kcal)</Typography>
              <Typography variant="body2" sx={{ fontWeight: 'bold' }}>{data.goalProgress.calories}%</Typography>
            </Box>
            <LinearProgress variant="determinate" value={data.goalProgress.calories} />
          </Box>

          <Box sx={{ mb: 2 }}>
            <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 1 }}>
              <Typography variant="body2">Protein ({data.todayTotalProtein.toFixed(1)} / {data.profile.protein_goal_g} g)</Typography>
              <Typography variant="body2" sx={{ fontWeight: 'bold' }}>{data.goalProgress.protein}%</Typography>
            </Box>
            <LinearProgress variant="determinate" value={data.goalProgress.protein} />
          </Box>

          <Box sx={{ mb: 2 }}>
            <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 1 }}>
              <Typography variant="body2">Carbs ({data.todayTotalCarbs.toFixed(1)} / {data.profile.carbs_goal_g} g)</Typography>
              <Typography variant="body2" sx={{ fontWeight: 'bold' }}>{data.goalProgress.carbs}%</Typography>
            </Box>
            <LinearProgress variant="determinate" value={data.goalProgress.carbs} />
          </Box>

          <Box>
            <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 1 }}>
              <Typography variant="body2">Fat ({data.todayTotalFat.toFixed(1)} / {data.profile.fat_goal_g} g)</Typography>
              <Typography variant="body2" sx={{ fontWeight: 'bold' }}>{data.goalProgress.fat}%</Typography>
            </Box>
            <LinearProgress variant="determinate" value={data.goalProgress.fat} />
          </Box>
        </CardContent>
      </Card>

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
                      <TableCell>{new Date(meal.date).toLocaleDateString([], { month: 'short', day: 'numeric' })}</TableCell>
                      <TableCell align="right">{meal.totalKcal}</TableCell>
                      <TableCell align="right">{meal.mealCount}</TableCell>
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
        <CardHeader title="Top Foods (last 7 days)" />
        <CardContent>
          {data.topFoods.length > 0 ? (
            <TableContainer>
              <Table>
                <TableHead>
                  <TableRow>
                    <TableCell>Food Name</TableCell>
                    <TableCell align="right">Times Logged</TableCell>
                    <TableCell align="right">Consumed kcal</TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {data.topFoods.map((food, index) => (
                    <TableRow key={index}>
                      <TableCell>{food.name}</TableCell>
                      <TableCell align="right">{food.count}</TableCell>
                      <TableCell align="right">{food.totalKcal}</TableCell>
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

      <Card sx={{ mt: 4 }}>
        <CardHeader title="Correction Analytics (last 30 days)" />
        <CardContent>
          <Box sx={{ display: 'grid', gridTemplateColumns: { xs: '1fr', sm: '1fr 1fr', md: '1fr 1fr 1fr 1fr' }, gap: 2, mb: 3 }}>
            <Card variant="outlined">
              <CardContent>
                <Typography color="textSecondary" gutterBottom>
                  Total Corrections
                </Typography>
                <Typography variant="h5" sx={{ fontWeight: 'bold' }}>
                  {data.correctionsAnalytics.count}
                </Typography>
              </CardContent>
            </Card>
            <Card variant="outlined">
              <CardContent>
                <Typography color="textSecondary" gutterBottom>
                  Avg Grams Delta
                </Typography>
                <Typography variant="h5" sx={{ fontWeight: 'bold' }}>
                  {data.correctionsAnalytics.avg_grams_delta}
                </Typography>
              </CardContent>
            </Card>
            <Card variant="outlined">
              <CardContent>
                <Typography color="textSecondary" gutterBottom>
                  Unique Corrected Labels
                </Typography>
                <Typography variant="h5" sx={{ fontWeight: 'bold' }}>
                  {data.correctionsAnalytics.correction_frequency.by_corrected_label.length}
                </Typography>
              </CardContent>
            </Card>
            <Card variant="outlined">
              <CardContent>
                <Typography color="textSecondary" gutterBottom>
                  Auto-Adjust Status
                </Typography>
                <Typography variant="h5" sx={{ fontWeight: 'bold' }}>
                  {data.correctionsAnalytics.feedback_rules?.enabled ? 'Enabled' : 'Disabled'}
                </Typography>
                <Typography variant="caption" color="textSecondary">
                  Hit rate: {data.correctionsAnalytics.feedback_rules?.metrics.rule_hit_rate_pct ?? 0}% · Active rules: {data.correctionsAnalytics.feedback_rules?.active_rule_count ?? 0}
                </Typography>
                <Typography variant="caption" color="textSecondary" sx={{ display: 'block', mt: 0.5 }}>
                  Last changed: {data.correctionsAnalytics.feedback_rules?.last_change?.updated_by ?? 'n/a'}{data.correctionsAnalytics.feedback_rules?.last_change?.updated_at ? ` @ ${new Date(data.correctionsAnalytics.feedback_rules.last_change.updated_at).toLocaleString()}` : ''}
                </Typography>
                <Box sx={{ mt: 2 }}>
                  <Button
                    size="small"
                    variant="outlined"
                    onClick={handleToggleFeedbackRules}
                    disabled={updatingFeedbackRules || !data.correctionsAnalytics.feedback_rules}
                  >
                    {updatingFeedbackRules
                      ? 'Updating...'
                      : data.correctionsAnalytics.feedback_rules?.enabled
                        ? 'Disable Auto-Adjust'
                        : 'Enable Auto-Adjust'}
                  </Button>
                </Box>
              </CardContent>
            </Card>
          </Box>

          <Typography variant="subtitle1" sx={{ mb: 1, fontWeight: 'bold' }}>
            Top Corrected Labels
          </Typography>
          {data.correctionsAnalytics.top_corrected_labels.length > 0 ? (
            <TableContainer>
              <Table size="small">
                <TableHead>
                  <TableRow>
                    <TableCell>Label</TableCell>
                    <TableCell align="right">Corrections</TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {data.correctionsAnalytics.top_corrected_labels.slice(0, 10).map((entry, index) => (
                    <TableRow key={`${entry.label}-${index}`}>
                      <TableCell>{entry.label}</TableCell>
                      <TableCell align="right">{entry.count}</TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </TableContainer>
          ) : (
            <Typography color="textSecondary">No correction data in selected window.</Typography>
          )}
        </CardContent>
      </Card>
    </Box>
  );
}
