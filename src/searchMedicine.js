import axios from "axios";

export const fetchMedicineUses = async (medicineName) => {
  try {
    const response = await axios.get(`https://api.fda.gov/drug/label.json?search=${medicineName}`);
    return response.data.results[0]?.indications_and_usage || "No information found";
  } catch (error) {
    console.error("Error fetching medicine details:", error);
    return "Error retrieving data";
  }
};
