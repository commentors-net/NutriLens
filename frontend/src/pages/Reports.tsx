import { useState, useEffect } from "react";
import {
  Card,
  Typography,
  Select,
  MenuItem,
  InputLabel,
  FormControl,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Paper,
  Checkbox,
  Button,
  Box,
  TextField,
  Alert,
  IconButton,
  Tooltip,
} from "@mui/material";
import DeleteIcon from '@mui/icons-material/Delete';
import FilterListIcon from '@mui/icons-material/FilterList';
import { peopleApi, typesApi, absencesApi } from "@services/api";
import type { Person, LeaveType, Absence } from "@services/api";

export default function Reports() {
  const [people, setPeople] = useState<Person[]>([]);
  const [types, setTypes] = useState<LeaveType[]>([]);
  const [absences, setAbsences] = useState<Absence[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  // Filter states
  const [selectedPerson, setSelectedPerson] = useState<number | string>("");
  const [selectedType, setSelectedType] = useState<number | string>("");
  const [dateFrom, setDateFrom] = useState("");
  const [dateTo, setDateTo] = useState("");

  // Selection states
  const [selectedIds, setSelectedIds] = useState<Set<number>>(new Set());

  // Load people and types on mount
  useEffect(() => {
    const fetchData = async () => {
      try {
        const [peopleData, typesData] = await Promise.all([
          peopleApi.getAll(),
          typesApi.getAll(),
        ]);
        setPeople(peopleData);
        setTypes(typesData);
      } catch (err) {
        console.error("Failed to fetch data:", err);
        setError("Failed to load filter options. Please refresh the page.");
      }
    };
    fetchData();
  }, []);

  // Load absences on mount and whenever filters change
  useEffect(() => {
    fetchAbsences();
  }, [selectedPerson, selectedType, dateFrom, dateTo]);

  const fetchAbsences = async () => {
    setLoading(true);
    setError(null);
    try {
      const params: any = {};
      if (selectedPerson) params.person_id = Number(selectedPerson);
      if (selectedType) params.type_id = Number(selectedType);
      if (dateFrom) params.date_from = dateFrom;
      if (dateTo) params.date_to = dateTo;

      const data = await absencesApi.getAll(params);
      setAbsences(data);
    } catch (err) {
      console.error("Failed to fetch absences:", err);
      setError("Failed to load absences. Please try again.");
    } finally {
      setLoading(false);
    }
  };

  const handleSelectAll = (checked: boolean) => {
    if (checked) {
      setSelectedIds(new Set(absences.map((a) => a.id)));
    } else {
      setSelectedIds(new Set());
    }
  };

  const handleSelectOne = (id: number, checked: boolean) => {
    const newSelected = new Set(selectedIds);
    if (checked) {
      newSelected.add(id);
    } else {
      newSelected.delete(id);
    }
    setSelectedIds(newSelected);
  };

  const handleToggleApplied = async (id: number, currentValue: number) => {
    try {
      const newValue = currentValue === 1 ? 0 : 1;
      await absencesApi.update(id, { applied: newValue });
      
      // Update local state
      setAbsences(
        absences.map((a) => (a.id === id ? { ...a, applied: newValue } : a))
      );
      setSuccess(`Record marked as ${newValue === 1 ? "applied" : "not applied"}`);
      setTimeout(() => setSuccess(null), 3000);
    } catch (err) {
      console.error("Failed to update applied status:", err);
      setError("Failed to update applied status. Please try again.");
    }
  };

  const handleBulkUpdateApplied = async (applied: number) => {
    if (selectedIds.size === 0) {
      setError("Please select at least one record");
      return;
    }

    try {
      await absencesApi.bulkUpdateApplied(Array.from(selectedIds), applied);
      
      // Update local state
      setAbsences(
        absences.map((a) =>
          selectedIds.has(a.id) ? { ...a, applied } : a
        )
      );
      setSelectedIds(new Set());
      setSuccess(`${selectedIds.size} record(s) marked as ${applied === 1 ? "applied" : "not applied"}`);
      setTimeout(() => setSuccess(null), 3000);
    } catch (err) {
      console.error("Failed to bulk update:", err);
      setError("Failed to update records. Please try again.");
    }
  };

  const handleDeleteOne = async (id: number) => {
    if (!confirm("Are you sure you want to delete this record?")) {
      return;
    }

    try {
      await absencesApi.delete(id);
      setAbsences(absences.filter((a) => a.id !== id));
      setSuccess("Record deleted successfully");
      setTimeout(() => setSuccess(null), 3000);
    } catch (err) {
      console.error("Failed to delete record:", err);
      setError("Failed to delete record. Please try again.");
    }
  };

  const handleBulkDelete = async () => {
    if (selectedIds.size === 0) {
      setError("Please select at least one record to delete");
      return;
    }

    if (!confirm(`Are you sure you want to delete ${selectedIds.size} record(s)?`)) {
      return;
    }

    try {
      await absencesApi.bulkDelete(Array.from(selectedIds));
      setAbsences(absences.filter((a) => !selectedIds.has(a.id)));
      setSelectedIds(new Set());
      setSuccess(`${selectedIds.size} record(s) deleted successfully`);
      setTimeout(() => setSuccess(null), 3000);
    } catch (err) {
      console.error("Failed to bulk delete:", err);
      setError("Failed to delete records. Please try again.");
    }
  };

  const clearFilters = () => {
    setSelectedPerson("");
    setSelectedType("");
    setDateFrom("");
    setDateTo("");
  };

  const getPersonName = (personId: number): string => {
    return people.find((p) => p.id === personId)?.name || "Unknown";
  };

  const getTypeName = (typeId: number): string => {
    return types.find((t) => t.id === typeId)?.name || "Unknown";
  };

  const allSelected = absences.length > 0 && selectedIds.size === absences.length;
  const someSelected = selectedIds.size > 0 && selectedIds.size < absences.length;

  return (
    <Box sx={{ p: { xs: 2, sm: 3, md: 4 } }}>
      <Typography variant="h4" sx={{ mb: 3 }}>
        Reports
      </Typography>

      {error && (
        <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError(null)}>
          {error}
        </Alert>
      )}

      {success && (
        <Alert severity="success" sx={{ mb: 2 }} onClose={() => setSuccess(null)}>
          {success}
        </Alert>
      )}

      {/* Filters */}
      <Card sx={{ p: { xs: 2, sm: 3 }, mb: 3 }}>
        <Box sx={{ display: "flex", alignItems: "center", mb: 2 }}>
          <FilterListIcon sx={{ mr: 1 }} />
          <Typography variant="h6">Filters</Typography>
        </Box>
        <Box sx={{ display: "flex", gap: 2, flexWrap: "wrap" }}>
          <FormControl sx={{ minWidth: { xs: "100%", sm: 200 } }}>
            <InputLabel>Person</InputLabel>
            <Select
              value={selectedPerson}
              onChange={(e) => setSelectedPerson(e.target.value)}
              label="Person"
            >
              <MenuItem value="">All</MenuItem>
              {people.map((person) => (
                <MenuItem key={person.id} value={person.id}>
                  {person.name}
                </MenuItem>
              ))}
            </Select>
          </FormControl>

          <FormControl sx={{ minWidth: { xs: "100%", sm: 200 } }}>
            <InputLabel>Leave Type</InputLabel>
            <Select
              value={selectedType}
              onChange={(e) => setSelectedType(e.target.value)}
              label="Leave Type"
            >
              <MenuItem value="">All</MenuItem>
              {types.map((type) => (
                <MenuItem key={type.id} value={type.id}>
                  {type.name}
                </MenuItem>
              ))}
            </Select>
          </FormControl>

          <TextField
            label="Date From"
            type="date"
            value={dateFrom}
            onChange={(e) => setDateFrom(e.target.value)}
            InputLabelProps={{ shrink: true }}
            sx={{ minWidth: { xs: "100%", sm: 180 } }}
          />

          <TextField
            label="Date To"
            type="date"
            value={dateTo}
            onChange={(e) => setDateTo(e.target.value)}
            InputLabelProps={{ shrink: true }}
            sx={{ minWidth: { xs: "100%", sm: 180 } }}
          />

          <Button
            variant="outlined"
            onClick={clearFilters}
            sx={{ height: 56, minWidth: { xs: "100%", sm: "auto" } }}
          >
            Clear Filters
          </Button>
        </Box>
      </Card>

      {/* Bulk Actions */}
      {selectedIds.size > 0 && (
        <Card sx={{ p: 2, mb: 2, bgcolor: "primary.light" }}>
          <Box sx={{ display: "flex", alignItems: "center", gap: 2, flexWrap: "wrap" }}>
            <Typography variant="body1" sx={{ color: "primary.contrastText" }}>
              {selectedIds.size} record(s) selected
            </Typography>
            <Button
              variant="contained"
              color="success"
              size="small"
              onClick={() => handleBulkUpdateApplied(1)}
              sx={{ minWidth: { xs: "100%", sm: "auto" } }}
            >
              Mark as Applied
            </Button>
            <Button
              variant="contained"
              color="warning"
              size="small"
              onClick={() => handleBulkUpdateApplied(0)}
              sx={{ minWidth: { xs: "100%", sm: "auto" } }}
            >
              Mark as Not Applied
            </Button>
            <Button
              variant="contained"
              color="error"
              size="small"
              startIcon={<DeleteIcon />}
              onClick={handleBulkDelete}
              sx={{ minWidth: { xs: "100%", sm: "auto" } }}
            >
              Delete Selected
            </Button>
          </Box>
        </Card>
      )}

      {/* Results Table */}
      <TableContainer component={Paper} sx={{ overflowX: 'auto' }}>
        <Table>
          <TableHead>
            <TableRow>
              <TableCell padding="checkbox">
                <Checkbox
                  checked={allSelected}
                  indeterminate={someSelected}
                  onChange={(e) => handleSelectAll(e.target.checked)}
                />
              </TableCell>
              <TableCell>Date</TableCell>
              <TableCell>Person</TableCell>
              <TableCell>Leave Type</TableCell>
              <TableCell>Duration</TableCell>
              <TableCell>Reason</TableCell>
              <TableCell align="center">Applied</TableCell>
              <TableCell align="center">Actions</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {loading ? (
              <TableRow>
                <TableCell colSpan={8} align="center">
                  Loading...
                </TableCell>
              </TableRow>
            ) : absences.length === 0 ? (
              <TableRow>
                <TableCell colSpan={8} align="center">
                  No records found
                </TableCell>
              </TableRow>
            ) : (
              absences.map((absence) => (
                <TableRow
                  key={absence.id}
                  sx={{
                    bgcolor: absence.applied === 1 ? "success.light" : "inherit",
                    "&:hover": { bgcolor: "action.hover" },
                  }}
                >
                  <TableCell padding="checkbox">
                    <Checkbox
                      checked={selectedIds.has(absence.id)}
                      onChange={(e) =>
                        handleSelectOne(absence.id, e.target.checked)
                      }
                    />
                  </TableCell>
                  <TableCell>{absence.date}</TableCell>
                  <TableCell>{getPersonName(absence.person_id)}</TableCell>
                  <TableCell>{getTypeName(absence.type_id)}</TableCell>
                  <TableCell>{absence.duration}</TableCell>
                  <TableCell>{absence.reason}</TableCell>
                  <TableCell align="center">
                    <Checkbox
                      checked={absence.applied === 1}
                      onChange={() =>
                        handleToggleApplied(absence.id, absence.applied)
                      }
                      color="success"
                    />
                  </TableCell>
                  <TableCell align="center">
                    <Tooltip title="Delete">
                      <IconButton
                        color="error"
                        size="small"
                        onClick={() => handleDeleteOne(absence.id)}
                      >
                        <DeleteIcon />
                      </IconButton>
                    </Tooltip>
                  </TableCell>
                </TableRow>
              ))
            )}
          </TableBody>
        </Table>
      </TableContainer>

      <Box sx={{ mt: 2 }}>
        <Typography variant="body2" color="text.secondary">
          Total records: {absences.length}
        </Typography>
      </Box>
    </Box>
  );
}
