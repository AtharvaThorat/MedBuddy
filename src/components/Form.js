import React, { useState } from "react";
import axios from 'axios';
import "./Form.css";

const Form = () => {
    const [numMeds, setNumMeds] = useState(0);
    const [medicines, setMedicines] = useState([]);
    const [successMessage, setSuccessMessage] = useState("");
    const [errorMessage, setErrorMessage] = useState("");

    const handleNumMedsChange = (e) => {
        const count = parseInt(e.target.value, 10) || 0;
        setMedicines((prevMeds) => {
            const newMeds = [...prevMeds];

            while (newMeds.length < count) {
                newMeds.push({ name: "", doses: 1, times: [""] });
            }

            return newMeds.slice(0, count);
        });

        setNumMeds(count);
    };

    const handleMedicineChange = (index, field, value) => {
        setMedicines((prevMeds) => {
            const updatedMeds = [...prevMeds];
            updatedMeds[index][field] = value;

            if (field === "doses") {
                const doseCount = parseInt(value, 10) || 1;
                const currentTimes = updatedMeds[index].times.slice(0, doseCount);
                updatedMeds[index].times = [...currentTimes, ...Array(Math.max(0, doseCount - currentTimes.length)).fill("")];
            }

            return updatedMeds;
        });
    };

    const handleTimeChange = (medIndex, timeIndex, value) => {
        setMedicines((prevMeds) => {
            const updatedMeds = [...prevMeds];
            updatedMeds[medIndex].times[timeIndex] = value;
            return updatedMeds;
        });
    };

    const handleSubmit = async (e) => {
        e.preventDefault();
        setSuccessMessage("");
        setErrorMessage("");

        // Check for missing required fields
        let missingFields = [];

        const name = document.getElementById("name").value.trim();
        const age = document.getElementById("age").value.trim();
        const doctor = document.getElementById("doctor").value.trim();
        const numMedsInput = document.getElementById("numMeds").value.trim();

        if (!name) missingFields.push("Name");
        if (!age) missingFields.push("Age");
        if (!doctor) missingFields.push("Doctor Name");
        if (!numMedsInput || numMeds === 0) missingFields.push("Number of Medicines");

        medicines.forEach((med, index) => {
            if (!med.name) missingFields.push(`Medicine ${index + 1} Name`);
            if (!med.doses || med.doses < 1) missingFields.push(`Doses for Medicine ${index + 1}`);

            med.times.forEach((time, timeIndex) => {
                if (!time) missingFields.push(`Time ${timeIndex + 1} for Medicine ${index + 1}`);
            });
        });

        if (missingFields.length > 0) {
            alert(`Please fill in the following fields:\n\n${missingFields.join("\n")}`);
            return;
        }

        // Prepare form data for submission
        const formData = {
            name: name,
            age: parseInt(age, 10),
            doctor: doctor,
            medicines: medicines
        };

        try {
            // Send data to backend
            const response = await axios.post('http://localhost:5000/submit-form', formData, {
                headers: {
                    'Content-Type': 'application/json'
                }
            });
            
            // Handle successful submission
            setSuccessMessage("🎉 Good job! Form has been saved successfully!");
            
            // Reset form
            document.getElementById("name").value = "";
            document.getElementById("age").value = "";
            document.getElementById("doctor").value = "";
            document.getElementById("numMeds").value = "0";
            setNumMeds(0);
            setMedicines([]);

        } catch (error) {
            // Detailed error handling
            console.error('Submission error:', error);
            
            let errorMsg = "Error submitting form. Please try again.";
            
            if (error.response) {
                // The request was made and the server responded with a status code
                // that falls out of the range of 2xx
                errorMsg = error.response.data.error || 
                           error.response.data.message || 
                           "Server responded with an error.";
                console.error('Error details:', error.response.data);
            } else if (error.request) {
                // The request was made but no response was received
                errorMsg = "No response received from the server. Please check your connection.";
            }
            
            setErrorMessage(errorMsg);
        }
    };

    return (
        <div className="outer-container">
            <div className="form-container">
                <h2>Medicine Reminder Form</h2>
                <form onSubmit={handleSubmit}>
                    <label htmlFor="name" className="required">Name:</label>
                    <input type="text" id="name" name="name" required placeholder="Enter your name" />

                    <label htmlFor="age" className="required">Age:</label>
                    <input type="number" id="age" name="age" required placeholder="Enter your age" />

                    <label htmlFor="doctor" className="required">Doctor Name:</label>
                    <input type="text" id="doctor" name="doctor" required placeholder="Doctor's Name" />

                    <label htmlFor="numMeds" className="required">Number of Medicines:</label>
                    <input
                        type="number"
                        id="numMeds"
                        name="numMeds"
                        min="1"
                        value={numMeds}
                        onChange={handleNumMedsChange}
                        required
                        placeholder="Enter number of medicines"
                    />

                    <div id="medsContainer" className="meds-container">
                        {medicines.map((med, index) => (
                            <div key={index} className="medicine-section">
                                <label className="required">Medicine {index + 1} Name:</label>
                                <input type="text" value={med.name} onChange={(e) => handleMedicineChange(index, "name", e.target.value)} required placeholder="Enter medicine name" />

                                <label className="required">Number of Doses per Day:</label>
                                <input type="number" value={med.doses} onChange={(e) => handleMedicineChange(index, "doses", e.target.value)} required min="1" />

                                {med.times.map((time, timeIndex) => (
                                    <div key={timeIndex}>
                                        <label className="required">Reminder Time {timeIndex + 1}:</label>
                                        <input type="time" value={time} onChange={(e) => handleTimeChange(index, timeIndex, e.target.value)} required />
                                    </div>
                                ))}
                            </div>
                        ))}
                    </div>

                    <button type="submit" className="btn">Submit</button>
                </form>

                {successMessage && <div className="success-message">{successMessage}</div>}
                {errorMessage && <div className="error-message">{errorMessage}</div>}
            </div>
        </div>
    );
};

export default Form;