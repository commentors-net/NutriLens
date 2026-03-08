import { useEffect, useState } from "react";
import {
  Alert,
  Box,
  Button,
  Card,
  CardContent,
  CircularProgress,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  IconButton,
  Stack,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  TextField,
  Typography,
  Paper,
  InputAdornment,
  Chip,
} from "@mui/material";
import AddIcon from "@mui/icons-material/Add";
import EditIcon from "@mui/icons-material/Edit";
import DeleteIcon from "@mui/icons-material/Delete";
import SearchIcon from "@mui/icons-material/Search";
import { foodsApi } from "@services/api";
import type { Food, FoodCreate } from "@services/api";

export default function NutriLensNutrition() {
  const [foods, setFoods] = useState<Food[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [searchTerm, setSearchTerm] = useState("");
  const [openDialog, setOpenDialog] = useState(false);
  const [editingFood, setEditingFood] = useState<Food | null>(null);
  const [formData, setFormData] = useState<FoodCreate>({
    name: "",
    kcal_per_100g: 0,
    protein_per_100g: 0,
    carbs_per_100g: 0,
    fat_per_100g: 0,
  });
  const [submitting, setSubmitting] = useState(false);
  const [deleting, setDeleting] = useState("");

  const fetchFoods = async () => {
    setLoading(true);
    setError("");
    try {
      const data = await foodsApi.listAll();
      setFoods(data);
    } catch (err: any) {
      const message = err?.response?.data?.detail || "Failed to load foods";
      setError(String(message));
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchFoods();
  }, []);

  const filteredFoods = foods.filter((food) =>
    food.name.toLowerCase().includes(searchTerm.toLowerCase())
  );

  const handleOpenDialog = (food?: Food) => {
    if (food) {
      setEditingFood(food);
      setFormData({
        name: food.name,
        kcal_per_100g: food.kcal_per_100g,
        protein_per_100g: food.protein_per_100g,
        carbs_per_100g: food.carbs_per_100g,
        fat_per_100g: food.fat_per_100g,
      });
    } else {
      setEditingFood(null);
      setFormData({
        name: "",
        kcal_per_100g: 0,
        protein_per_100g: 0,
        carbs_per_100g: 0,
        fat_per_100g: 0,
      });
    }
    setOpenDialog(true);
  };

  const handleCloseDialog = () => {
    setOpenDialog(false);
    setEditingFood(null);
  };

  const handleSubmit = async () => {
    if (!formData.name.trim()) {
      alert("Food name is required");
      return;
    }

    setSubmitting(true);
    try {
      if (editingFood) {
        // Update
        await foodsApi.update(editingFood.food_id, formData);
        setFoods((prev) =>
          prev.map((f) =>
            f.food_id === editingFood.food_id
              ? { ...f, ...formData }
              : f
          )
        );
      } else {
        // Create
        const newFood = await foodsApi.create(formData);
        setFoods((prev) => [...prev, newFood]);
      }
      handleCloseDialog();
    } catch (err: any) {
      const message = err?.response?.data?.detail || "Failed to save food";
      alert(message);
    } finally {
      setSubmitting(false);
    }
  };

  const handleDelete = async (food: Food) => {
    if (!window.confirm(`Delete "${food.name}"?`)) return;

    setDeleting(food.food_id);
    try {
      await foodsApi.delete(food.food_id);
      setFoods((prev) => prev.filter((f) => f.food_id !== food.food_id));
    } catch (err: any) {
      const message = err?.response?.data?.detail || "Failed to delete food";
      alert(message);
    } finally {
      setDeleting("");
    }
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
      <Stack direction={{ xs: "column", sm: "row" }} spacing={2} alignItems={{ xs: "flex-start", sm: "center" }} justifyContent="space-between" sx={{ mb: 4 }}>
        <Box>
          <Typography variant="h5" sx={{ fontWeight: 600 }}>
            Food Database
          </Typography>
          <Typography variant="body2" color="text.secondary">
            {foods.length} foods stored
          </Typography>
        </Box>
        <Button variant="contained" startIcon={<AddIcon />} onClick={() => handleOpenDialog()}>
          Add Food
        </Button>
      </Stack>

      {error && <Alert severity="error" sx={{ mb: 3 }}>{error}</Alert>}

      {/* Search Bar */}
      <TextField
        placeholder="Search foods..."
        value={searchTerm}
        onChange={(e) => setSearchTerm(e.target.value)}
        fullWidth
        size="small"
        slotProps={{
          input: {
            startAdornment: (
              <InputAdornment position="start">
                <SearchIcon />
              </InputAdornment>
            ),
          },
        }}
        sx={{ mb: 3 }}
      />

      {/* Foods Table */}
      {filteredFoods.length === 0 ? (
        <Card>
          <CardContent>
            <Typography color="text.secondary" align="center" sx={{ py: 3 }}>
              {foods.length === 0 ? "No foods in database" : "No foods match your search"}
            </Typography>
          </CardContent>
        </Card>
      ) : (
        <TableContainer component={Paper}>
          <Table>
            <TableHead>
              <TableRow sx={{ bgcolor: "background.default" }}>
                <TableCell sx={{ fontWeight: 600 }}>Food Name</TableCell>
                <TableCell align="right" sx={{ fontWeight: 600 }}>
                  Kcal/100g
                </TableCell>
                <TableCell align="right" sx={{ fontWeight: 600 }}>
                  Protein (g)
                </TableCell>
                <TableCell align="right" sx={{ fontWeight: 600 }}>
                  Carbs (g)
                </TableCell>
                <TableCell align="right" sx={{ fontWeight: 600 }}>
                  Fat (g)
                </TableCell>
                <TableCell align="center" sx={{ fontWeight: 600, width: 100 }}>
                  Actions
                </TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {filteredFoods.map((food) => (
                <TableRow key={food.food_id} hover>
                  <TableCell>
                    <Stack direction="column">
                      <Typography sx={{ fontWeight: 500 }}>{food.name}</Typography>
                      <Typography variant="caption" color="text.secondary">
                        {food.food_id.slice(0, 8)}...
                      </Typography>
                    </Stack>
                  </TableCell>
                  <TableCell align="right">
                    <Chip label={food.kcal_per_100g} size="small" color="error" variant="filled" />
                  </TableCell>
                  <TableCell align="right">{food.protein_per_100g.toFixed(1)}g</TableCell>
                  <TableCell align="right">{food.carbs_per_100g.toFixed(1)}g</TableCell>
                  <TableCell align="right">{food.fat_per_100g.toFixed(1)}g</TableCell>
                  <TableCell align="center">
                    <IconButton
                      size="small"
                      onClick={() => handleOpenDialog(food)}
                      color="primary"
                      title="Edit"
                    >
                      <EditIcon fontSize="small" />
                    </IconButton>
                    <IconButton
                      size="small"
                      onClick={() => handleDelete(food)}
                      disabled={deleting === food.food_id}
                      color="error"
                      title="Delete"
                    >
                      <DeleteIcon fontSize="small" />
                    </IconButton>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </TableContainer>
      )}

      {/* Create/Edit Dialog */}
      <Dialog open={openDialog} onClose={handleCloseDialog} maxWidth="sm" fullWidth>
        <DialogTitle>
          {editingFood ? `Edit Food: ${editingFood.name}` : "Add New Food"}
        </DialogTitle>
        <DialogContent sx={{ pt: 2 }}>
          <Stack spacing={2}>
            <TextField
              label="Food Name"
              value={formData.name}
              onChange={(e) => setFormData({ ...formData, name: e.target.value })}
              fullWidth
              autoFocus
            />
            <TextField
              label="Kcal per 100g"
              type="number"
              value={formData.kcal_per_100g}
              onChange={(e) => setFormData({ ...formData, kcal_per_100g: parseInt(e.target.value) || 0 })}
              fullWidth
            />
            <TextField
              label="Protein per 100g (g)"
              type="number"
              inputProps={{ step: "0.1" }}
              value={formData.protein_per_100g}
              onChange={(e) => setFormData({ ...formData, protein_per_100g: parseFloat(e.target.value) || 0 })}
              fullWidth
            />
            <TextField
              label="Carbs per 100g (g)"
              type="number"
              inputProps={{ step: "0.1" }}
              value={formData.carbs_per_100g}
              onChange={(e) => setFormData({ ...formData, carbs_per_100g: parseFloat(e.target.value) || 0 })}
              fullWidth
            />
            <TextField
              label="Fat per 100g (g)"
              type="number"
              inputProps={{ step: "0.1" }}
              value={formData.fat_per_100g}
              onChange={(e) => setFormData({ ...formData, fat_per_100g: parseFloat(e.target.value) || 0 })}
              fullWidth
            />
          </Stack>
        </DialogContent>
        <DialogActions>
          <Button onClick={handleCloseDialog}>Cancel</Button>
          <Button
            onClick={handleSubmit}
            variant="contained"
            disabled={submitting}
          >
            {submitting ? "Saving..." : "Save"}
          </Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
}
