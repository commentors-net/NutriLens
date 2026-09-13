import { useState, useRef, type ChangeEvent, type DragEvent } from 'react';
import {
  Box,
  Button,
  Card,
  CardContent,
  Typography,
  CircularProgress,
  Alert,
  Chip,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Paper,
  TextField,
  IconButton,
  Tooltip,
} from '@mui/material';
import CloudUploadIcon from '@mui/icons-material/CloudUpload';
import AutoAwesomeIcon from '@mui/icons-material/AutoAwesome';
import DeleteIcon from '@mui/icons-material/Delete';
import AddIcon from '@mui/icons-material/Add';
import CheckCircleIcon from '@mui/icons-material/CheckCircle';
import InfoOutlinedIcon from '@mui/icons-material/InfoOutlined';
import CameraAltIcon from '@mui/icons-material/CameraAlt';
import BookmarkAddedIcon from '@mui/icons-material/BookmarkAdded';
import {
  mealsApi,
  type AnalyzeMealResponse,
  type AnalyzeItem,
  type SaveMealRequestItem,
  type SaveMealPayload,
} from '@services/api';

interface EditableMealItem extends AnalyzeItem {
  isEdited?: boolean;
}

interface MealPhotoAnalyzerProps {
  onMealSaved?: () => void;
}

export default function MealPhotoAnalyzer({ onMealSaved }: MealPhotoAnalyzerProps) {
  const [selectedFiles, setSelectedFiles] = useState<File[]>([]);
  const [previews, setPreviews] = useState<string[]>([]);
  const [analyzing, setAnalyzing] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [saveSuccess, setSaveSuccess] = useState(false);
  const [analysisResult, setAnalysisResult] = useState<AnalyzeMealResponse | null>(null);
  const [editableItems, setEditableItems] = useState<EditableMealItem[]>([]);
  const [mealNotes, setMealNotes] = useState('');
  const [isDragOver, setIsDragOver] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const handleFiles = (files: FileList | null) => {
    if (!files || files.length === 0) return;

    setError(null);
    setSaveSuccess(false);

    const validFiles: File[] = [];
    const validTypes = ['image/jpeg', 'image/png', 'image/webp', 'image/jpg'];

    for (let i = 0; i < files.length; i++) {
      const file = files[i];
      if (validTypes.includes(file.type.toLowerCase())) {
        validFiles.push(file);
      }
    }

    if (validFiles.length === 0) {
      setError('Please upload valid food images (JPEG, PNG, or WEBP).');
      return;
    }

    const updatedFiles = [...selectedFiles, ...validFiles].slice(0, 8);
    setSelectedFiles(updatedFiles);

    // Generate previews
    const newPreviews = updatedFiles.map((file) => URL.createObjectURL(file));
    setPreviews(newPreviews);
  };

  const handleFileChange = (e: ChangeEvent<HTMLInputElement>) => {
    handleFiles(e.target.files);
    if (fileInputRef.current) {
      fileInputRef.current.value = '';
    }
  };

  const handleDragOver = (e: DragEvent<HTMLDivElement>) => {
    e.preventDefault();
    setIsDragOver(true);
  };

  const handleDragLeave = (e: DragEvent<HTMLDivElement>) => {
    e.preventDefault();
    setIsDragOver(false);
  };

  const handleDrop = (e: DragEvent<HTMLDivElement>) => {
    e.preventDefault();
    setIsDragOver(false);
    handleFiles(e.dataTransfer.files);
  };

  const removePhoto = (index: number) => {
    const updatedFiles = selectedFiles.filter((_, i) => i !== index);
    setSelectedFiles(updatedFiles);
    const updatedPreviews = updatedFiles.map((file) => URL.createObjectURL(file));
    setPreviews(updatedPreviews);
  };

  const clearAll = () => {
    setSelectedFiles([]);
    setPreviews([]);
    setAnalysisResult(null);
    setEditableItems([]);
    setError(null);
    setSaveSuccess(false);
    setMealNotes('');
  };

  const handleAnalyze = async () => {
    if (selectedFiles.length === 0) {
      setError('Please upload at least one photo of your meal.');
      return;
    }

    try {
      setAnalyzing(true);
      setError(null);
      setSaveSuccess(false);

      const browserLocale = (navigator.language || 'en_US').replace('-', '_');
      const metadata = {
        platform: 'web',
        app_version: '1.0.0',
        photo_count: selectedFiles.length,
        locale: browserLocale,
      };

      const result = await mealsApi.analyzeMealPhotos(selectedFiles, metadata);
      setAnalysisResult(result);
      setEditableItems(
        result.items.map((item) => ({
          ...item,
          original_label: item.original_label || item.label,
          original_grams_estimate: item.original_grams_estimate || item.grams_estimate,
        }))
      );
    } catch (err: any) {
      const msg =
        err?.response?.data?.detail ||
        err?.message ||
        'Food analysis failed. Please verify the backend server is running.';
      setError(typeof msg === 'string' ? msg : JSON.stringify(msg));
    } finally {
      setAnalyzing(false);
    }
  };

  const handleGramsChange = (index: number, newGrams: number) => {
    setEditableItems((prev) => {
      const copy = [...prev];
      const item = { ...copy[index] };
      const oldGrams = item.grams_estimate || 1;
      const ratio = newGrams / (oldGrams || 1);

      item.grams_estimate = Math.max(1, newGrams);
      item.macros = {
        kcal: Math.round(item.macros.kcal * ratio),
        protein_g: Number((item.macros.protein_g * ratio).toFixed(1)),
        carbs_g: Number((item.macros.carbs_g * ratio).toFixed(1)),
        fat_g: Number((item.macros.fat_g * ratio).toFixed(1)),
      };
      item.isEdited = true;
      copy[index] = item;
      return copy;
    });
  };

  const handleLabelChange = (index: number, newLabel: string) => {
    setEditableItems((prev) => {
      const copy = [...prev];
      copy[index] = { ...copy[index], label: newLabel, isEdited: true };
      return copy;
    });
  };

  const handleDeleteItem = (index: number) => {
    setEditableItems((prev) => prev.filter((_, i) => i !== index));
  };

  const handleAddItem = () => {
    const newItem: EditableMealItem = {
      item_id: 'custom_' + Date.now(),
      label: 'Custom Item',
      label_confidence: 1.0,
      grams_estimate: 100,
      grams_range: { min: 80, max: 120 },
      grams_confidence: 1.0,
      macros: {
        kcal: 100,
        protein_g: 5,
        carbs_g: 15,
        fat_g: 2,
      },
      original_label: 'Custom Item',
      original_grams_estimate: 100,
      isEdited: true,
    };
    setEditableItems((prev) => [...prev, newItem]);
  };

  const totalKcal = editableItems.reduce((acc, item) => acc + item.macros.kcal, 0);
  const totalProtein = editableItems.reduce((acc, item) => acc + item.macros.protein_g, 0);
  const totalCarbs = editableItems.reduce((acc, item) => acc + item.macros.carbs_g, 0);
  const totalFat = editableItems.reduce((acc, item) => acc + item.macros.fat_g, 0);

  const handleSaveMeal = async () => {
    if (editableItems.length === 0) {
      setError('Cannot save meal with no items.');
      return;
    }

    try {
      setSaving(true);
      setError(null);

      const items: SaveMealRequestItem[] = editableItems.map((item) => ({
        label: item.label,
        grams: item.grams_estimate,
        macros: item.macros,
        original_label: item.original_label || item.label,
        original_grams: item.original_grams_estimate || item.grams_estimate,
        corrected: item.isEdited || false,
      }));

      const payload: SaveMealPayload = {
        items,
        notes: mealNotes.trim() || undefined,
        timestamp: new Date().toISOString(),
      };

      await mealsApi.saveMealWithImages(payload, selectedFiles);

      setSaveSuccess(true);
      if (onMealSaved) {
        onMealSaved();
      }
    } catch (err: any) {
      const msg = err?.response?.data?.detail || err?.message || 'Failed to save meal.';
      setError(typeof msg === 'string' ? msg : JSON.stringify(msg));
    } finally {
      setSaving(false);
    }
  };

  return (
    <Card sx={{ p: { xs: 2, sm: 3 } }}>
      <CardContent sx={{ p: 0 }}>
        {/* Header */}
        <Box sx={{ display: 'flex', alignItems: 'center', mb: 2, gap: 1.5 }}>
          <AutoAwesomeIcon color='primary' sx={{ fontSize: 28 }} />
          <Box>
            <Typography variant='h6' fontWeight='bold'>
              AI Food Nutrition Analyzer
            </Typography>
            <Typography variant='body2' color='text.secondary'>
              Upload multi-angle photos of your meal for instant nutrient and macro recognition
            </Typography>
          </Box>
        </Box>

        {error && (
          <Alert severity='error' sx={{ mb: 2 }} onClose={() => setError(null)}>
            {error}
          </Alert>
        )}

        {saveSuccess && (
          <Alert
            severity='success'
            sx={{ mb: 2 }}
            action={
              <Button color='inherit' size='small' onClick={clearAll}>
                Log Another Meal
              </Button>
            }
          >
            Meal successfully analyzed, logged, and synced to your cloud database!
          </Alert>
        )}

        {/* Dropzone */}
        {!analysisResult && (
          <Box
            onDragOver={handleDragOver}
            onDragLeave={handleDragLeave}
            onDrop={handleDrop}
            sx={{
              border: '2px dashed',
              borderColor: isDragOver ? 'primary.main' : 'divider',
              borderRadius: 2,
              p: { xs: 3, sm: 4 },
              textAlign: 'center',
              backgroundColor: isDragOver ? 'action.hover' : 'background.default',
              cursor: 'pointer',
              transition: 'all 0.2s ease',
              mb: 3,
            }}
            onClick={() => fileInputRef.current?.click()}
          >
            <input
              type='file'
              ref={fileInputRef}
              onChange={handleFileChange}
              multiple
              accept='image/jpeg,image/png,image/webp'
              style={{ display: 'none' }}
            />
            <CloudUploadIcon sx={{ fontSize: 48, color: 'primary.main', mb: 1 }} />
            <Typography variant='subtitle1' fontWeight='600'>
              Drag & drop food photos here, or click to browse
            </Typography>
            <Typography variant='body2' color='text.secondary' sx={{ mt: 0.5 }}>
              Supports JPG, PNG, WEBP (up to 8 photos)
            </Typography>

            {/* Recommended angles chip guide */}
            <Box sx={{ display: 'flex', justifyContent: 'center', gap: 1, mt: 2, flexWrap: 'wrap' }}>
              <Chip
                icon={<CameraAltIcon fontSize='small' />}
                label='Shot 1: Top-Down (90°)'
                size='small'
                variant='outlined'
              />
              <Chip
                icon={<CameraAltIcon fontSize='small' />}
                label='Shot 2: 45° Angle (Volume)'
                size='small'
                variant='outlined'
              />
              <Chip
                icon={<CameraAltIcon fontSize='small' />}
                label='Shot 3: Closeup (Texture)'
                size='small'
                variant='outlined'
              />
            </Box>
          </Box>
        )}

        {/* Previews */}
        {previews.length > 0 && (
          <Box sx={{ mb: 3 }}>
            <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 1 }}>
              <Typography variant='subtitle2' fontWeight='bold'>
                Attached Photos ({previews.length})
              </Typography>
              {!analysisResult && (
                <Button size='small' color='secondary' onClick={clearAll}>
                  Clear All
                </Button>
              )}
            </Box>

            <Box sx={{ display: 'flex', gap: 1.5, overflowX: 'auto', pb: 1 }}>
              {previews.map((previewUrl, idx) => (
                <Box
                  key={idx}
                  sx={{
                    position: 'relative',
                    width: 100,
                    height: 100,
                    flexShrink: 0,
                    borderRadius: 2,
                    overflow: 'hidden',
                    border: '1px solid',
                    borderColor: 'divider',
                  }}
                >
                  <img
                    src={previewUrl}
                    alt={'Food shot ' + (idx + 1)}
                    style={{ width: '100%', height: '100%', objectFit: 'cover' }}
                  />
                  {!analysisResult && (
                    <IconButton
                      size='small'
                      onClick={(e) => {
                        e.stopPropagation();
                        removePhoto(idx);
                      }}
                      sx={{
                        position: 'absolute',
                        top: 2,
                        right: 2,
                        backgroundColor: 'rgba(0, 0, 0, 0.6)',
                        color: 'white',
                        '&:hover': { backgroundColor: 'rgba(0, 0, 0, 0.8)' },
                      }}
                    >
                      <DeleteIcon sx={{ fontSize: 14 }} />
                    </IconButton>
                  )}
                  <Box
                    sx={{
                      position: 'absolute',
                      bottom: 2,
                      left: 2,
                      backgroundColor: 'rgba(0, 0, 0, 0.65)',
                      color: 'white',
                      fontSize: 10,
                      px: 0.6,
                      py: 0.2,
                      borderRadius: 1,
                    }}
                  >
                    {'#' + (idx + 1)}
                  </Box>
                </Box>
              ))}

              {!analysisResult && (
                <Box
                  onClick={() => fileInputRef.current?.click()}
                  sx={{
                    width: 100,
                    height: 100,
                    flexShrink: 0,
                    borderRadius: 2,
                    border: '1px dashed',
                    borderColor: 'divider',
                    display: 'flex',
                    flexDirection: 'column',
                    alignItems: 'center',
                    justifyContent: 'center',
                    cursor: 'pointer',
                    '&:hover': { borderColor: 'primary.main', backgroundColor: 'action.hover' },
                  }}
                >
                  <AddIcon color='action' />
                  <Typography variant='caption' color='text.secondary'>
                    Add More
                  </Typography>
                </Box>
              )}
            </Box>
          </Box>
        )}

        {/* Action Button to trigger analysis */}
        {!analysisResult && selectedFiles.length > 0 && (
          <Box sx={{ textAlign: 'center', mb: 2 }}>
            <Button
              variant='contained'
              size='large'
              startIcon={analyzing ? <CircularProgress size={20} color='inherit' /> : <AutoAwesomeIcon />}
              onClick={handleAnalyze}
              disabled={analyzing}
              sx={{ px: 4, py: 1.2, fontWeight: 'bold' }}
            >
              {analyzing ? 'Analyzing Nutrition with AI…' : 'Analyze Meal Photos'}
            </Button>
          </Box>
        )}

        {/* Results Section */}
        {analysisResult && (
          <Box sx={{ mt: 2 }}>
            {/* Confidence and Guidance Banner */}
            <Box
              sx={{
                p: 2,
                borderRadius: 2,
                mb: 2.5,
                backgroundColor:
                  analysisResult.overall_confidence >= 0.7
                    ? 'success.light'
                    : analysisResult.overall_confidence >= 0.5
                    ? 'warning.light'
                    : 'error.light',
                color: 'text.primary',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
                flexWrap: 'wrap',
                gap: 1.5,
              }}
            >
              <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                {analysisResult.overall_confidence >= 0.7 ? (
                  <CheckCircleIcon color='success' />
                ) : (
                  <InfoOutlinedIcon color='warning' />
                )}
                <Typography variant='subtitle2' fontWeight='bold'>
                  Overall Confidence: {Math.round(analysisResult.overall_confidence * 100)}%
                </Typography>
                <Chip
                  label={
                    analysisResult.overall_confidence >= 0.7
                      ? 'High Confidence'
                      : analysisResult.overall_confidence >= 0.5
                      ? 'Moderate Confidence'
                      : 'Low Confidence'
                  }
                  size='small'
                  color={
                    analysisResult.overall_confidence >= 0.7
                      ? 'success'
                      : analysisResult.overall_confidence >= 0.5
                      ? 'warning'
                      : 'error'
                  }
                  sx={{ fontWeight: 'bold', height: 22 }}
                />
              </Box>

              <Button size='small' variant='outlined' onClick={clearAll}>
                New Analysis
              </Button>
            </Box>

            {/* AI Suggested Angles if needs more photos */}
            {(analysisResult.needs_more_photos ||
              (analysisResult.suggested_next_shots && analysisResult.suggested_next_shots.length > 0)) && (
              <Alert severity='info' sx={{ mb: 2.5 }}>
                <Typography variant='body2' fontWeight='bold'>
                  AI Multi-Angle Recommendations:
                </Typography>
                <Typography variant='caption'>
                  For better estimation accuracy, try capturing:
                </Typography>
                <Box sx={{ display: 'flex', gap: 1, mt: 0.5, flexWrap: 'wrap' }}>
                  {analysisResult.suggested_next_shots.map((shot, i) => (
                    <Chip key={i} label={shot} size='small' variant='filled' />
                  ))}
                </Box>
              </Alert>
            )}

            {/* Macro Total Cards */}
            <Box
              sx={{
                display: 'grid',
                gridTemplateColumns: { xs: '1fr 1fr', sm: '1fr 1fr 1fr 1fr' },
                gap: 2,
                mb: 3,
              }}
            >
              <Paper sx={{ p: 2, textAlign: 'center', bgcolor: 'primary.light', color: 'primary.contrastText' }}>
                <Typography variant='h5' fontWeight='bold'>
                  {totalKcal}
                </Typography>
                <Typography variant='body2'>Calories (kcal)</Typography>
              </Paper>
              <Paper sx={{ p: 2, textAlign: 'center', bgcolor: '#e3f2fd' }}>
                <Typography variant='h5' fontWeight='bold' color='#1976d2'>
                  {totalProtein.toFixed(1)}g
                </Typography>
                <Typography variant='body2' color='text.secondary'>
                  Protein
                </Typography>
              </Paper>
              <Paper sx={{ p: 2, textAlign: 'center', bgcolor: '#fff3e0' }}>
                <Typography variant='h5' fontWeight='bold' color='#ed6c02'>
                  {totalCarbs.toFixed(1)}g
                </Typography>
                <Typography variant='body2' color='text.secondary'>
                  Carbs
                </Typography>
              </Paper>
              <Paper sx={{ p: 2, textAlign: 'center', bgcolor: '#fbe9e7' }}>
                <Typography variant='h5' fontWeight='bold' color='#d32f2f'>
                  {totalFat.toFixed(1)}g
                </Typography>
                <Typography variant='body2' color='text.secondary'>
                  Fat
                </Typography>
              </Paper>
            </Box>

            {/* Detected Items Table */}
            <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 1 }}>
              <Typography variant='subtitle1' fontWeight='bold'>
                Detected Food Items
              </Typography>
              <Button startIcon={<AddIcon />} size='small' onClick={handleAddItem}>
                Add Item
              </Button>
            </Box>

            <TableContainer component={Paper} variant='outlined' sx={{ mb: 3 }}>
              <Table size='small'>
                <TableHead>
                  <TableRow sx={{ bgcolor: 'action.hover' }}>
                    <TableCell>Food Item</TableCell>
                    <TableCell align='right'>Portion (g)</TableCell>
                    <TableCell align='right'>Calories</TableCell>
                    <TableCell align='right'>Protein</TableCell>
                    <TableCell align='right'>Carbs</TableCell>
                    <TableCell align='right'>Fat</TableCell>
                    <TableCell align='right'>Actions</TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {editableItems.map((item, index) => (
                    <TableRow key={index} hover>
                      <TableCell>
                        <TextField
                          value={item.label}
                          size='small'
                          variant='standard'
                          onChange={(e) => handleLabelChange(index, e.target.value)}
                          InputProps={{ disableUnderline: !item.isEdited }}
                        />
                        {item.isEdited && (
                          <Chip label='Edited' size='small' color='primary' sx={{ ml: 1, height: 18, fontSize: 10 }} />
                        )}
                      </TableCell>
                      <TableCell align='right'>
                        <TextField
                          type='number'
                          value={item.grams_estimate}
                          size='small'
                          sx={{ width: 80 }}
                          inputProps={{ min: 1, step: 10 }}
                          onChange={(e) => handleGramsChange(index, parseInt(e.target.value) || 0)}
                        />
                      </TableCell>
                      <TableCell align='right'>{item.macros.kcal} kcal</TableCell>
                      <TableCell align='right'>{item.macros.protein_g}g</TableCell>
                      <TableCell align='right'>{item.macros.carbs_g}g</TableCell>
                      <TableCell align='right'>{item.macros.fat_g}g</TableCell>
                      <TableCell align='right'>
                        <Tooltip title='Remove item'>
                          <IconButton size='small' color='error' onClick={() => handleDeleteItem(index)}>
                            <DeleteIcon fontSize='small' />
                          </IconButton>
                        </Tooltip>
                      </TableCell>
                    </TableRow>
                  ))}
                  {editableItems.length === 0 && (
                    <TableRow>
                      <TableCell colSpan={7} align='center' sx={{ py: 3 }}>
                        <Typography color='text.secondary'>No food items listed. Click Add Item to enter one.</Typography>
                      </TableCell>
                    </TableRow>
                  )}
                </TableBody>
              </Table>
            </TableContainer>

            {/* Notes & Save Button */}
            <Box sx={{ mb: 2 }}>
              <TextField
                fullWidth
                size='small'
                label='Meal Notes (Optional)'
                placeholder='e.g. Healthy lunch with avocado salad'
                value={mealNotes}
                onChange={(e) => setMealNotes(e.target.value)}
                sx={{ mb: 2 }}
              />

              <Box sx={{ display: 'flex', gap: 2, justifyContent: 'flex-end' }}>
                <Button variant='outlined' onClick={clearAll} disabled={saving}>
                  Discard
                </Button>
                <Button
                  variant='contained'
                  color='success'
                  startIcon={saving ? <CircularProgress size={20} color='inherit' /> : <BookmarkAddedIcon />}
                  onClick={handleSaveMeal}
                  disabled={saving || editableItems.length === 0}
                  sx={{ px: 3, fontWeight: 'bold' }}
                >
                  {saving ? 'Saving Meal…' : 'Save Meal to Log'}
                </Button>
              </Box>
            </Box>
          </Box>
        )}
      </CardContent>
    </Card>
  );
}
