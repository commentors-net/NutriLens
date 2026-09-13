import { useState } from 'react';
import { Typography, Box, Grid, Paper, Button } from '@mui/material';
import { Link } from 'react-router-dom';
import DashboardIcon from '@mui/icons-material/Dashboard';
import RestaurantMenuIcon from '@mui/icons-material/RestaurantMenu';
import HistoryIcon from '@mui/icons-material/History';
import LocalDiningIcon from '@mui/icons-material/LocalDining';
import MealPhotoAnalyzer from '@/components/MealPhotoAnalyzer';

function NutriLensPortal() {
  const username = localStorage.getItem('username') || 'User';
  const [mealSavedCount, setMealSavedCount] = useState(0);

  return (
    <Box sx={{ maxWidth: 1000, mx: 'auto', mt: { xs: 2, sm: 3 }, px: { xs: 2, sm: 3 }, pb: 6 }}>
      {/* Welcome Header */}
      <Box sx={{ mb: 3 }}>
        <Typography variant="h4" fontWeight="bold" gutterBottom>
          NutriLens Food & Nutrition Hub
        </Typography>
        <Typography variant="body1" color="text.secondary">
          Welcome back, {username}. Log meal photos directly, get AI multimodal nutrition insights, or view your history.
        </Typography>
      </Box>

      {/* Quick Navigation Cards */}
      <Grid container spacing={2} sx={{ mb: 4 }}>
        <Grid size={{ xs: 6, sm: 3 }}>
          <Paper
            sx={{
              p: 2,
              textAlign: 'center',
              borderRadius: 2,
              transition: 'transform 0.2s, box-shadow 0.2s',
              '&:hover': { transform: 'translateY(-2px)', boxShadow: 3 },
            }}
          >
            <DashboardIcon color="primary" sx={{ fontSize: 32, mb: 0.5 }} />
            <Typography variant="subtitle2" fontWeight="bold">
              Dashboard
            </Typography>
            <Button component={Link} to="/nutrilens/dashboard" size="small" sx={{ mt: 0.5 }}>
              Open
            </Button>
          </Paper>
        </Grid>

        <Grid size={{ xs: 6, sm: 3 }}>
          <Paper
            sx={{
              p: 2,
              textAlign: 'center',
              borderRadius: 2,
              transition: 'transform 0.2s, box-shadow 0.2s',
              '&:hover': { transform: 'translateY(-2px)', boxShadow: 3 },
            }}
          >
            <RestaurantMenuIcon color="success" sx={{ fontSize: 32, mb: 0.5 }} />
            <Typography variant="subtitle2" fontWeight="bold">
              Meal Logs
            </Typography>
            <Button component={Link} to="/nutrilens/meals" size="small" color="success" sx={{ mt: 0.5 }}>
              View
            </Button>
          </Paper>
        </Grid>

        <Grid size={{ xs: 6, sm: 3 }}>
          <Paper
            sx={{
              p: 2,
              textAlign: 'center',
              borderRadius: 2,
              transition: 'transform 0.2s, box-shadow 0.2s',
              '&:hover': { transform: 'translateY(-2px)', boxShadow: 3 },
            }}
          >
            <HistoryIcon color="info" sx={{ fontSize: 32, mb: 0.5 }} />
            <Typography variant="subtitle2" fontWeight="bold">
              Trends & Export
            </Typography>
            <Button component={Link} to="/nutrilens/history" size="small" color="info" sx={{ mt: 0.5 }}>
              Trends
            </Button>
          </Paper>
        </Grid>

        <Grid size={{ xs: 6, sm: 3 }}>
          <Paper
            sx={{
              p: 2,
              textAlign: 'center',
              borderRadius: 2,
              transition: 'transform 0.2s, box-shadow 0.2s',
              '&:hover': { transform: 'translateY(-2px)', boxShadow: 3 },
            }}
          >
            <LocalDiningIcon color="warning" sx={{ fontSize: 32, mb: 0.5 }} />
            <Typography variant="subtitle2" fontWeight="bold">
              Foods Database
            </Typography>
            <Button component={Link} to="/nutrilens/nutrition" size="small" color="warning" sx={{ mt: 0.5 }}>
              Browse
            </Button>
          </Paper>
        </Grid>
      </Grid>

      {/* Main Direct Food Photo Analyzer */}
      <MealPhotoAnalyzer
        key={mealSavedCount}
        onMealSaved={() => setMealSavedCount((c) => c + 1)}
      />
    </Box>
  );
}

export default NutriLensPortal;
