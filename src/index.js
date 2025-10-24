import React from 'react';
import ReactDOM from 'react-dom/client';
import {BrowserRouter as Router,Routes,Route} from 'react-router-dom';
import App from './App';
import Form from './components/Form';
import './index.css';
import reportWebVitals from './reportWebVitals';
import CameraScanner from "./components/CameraScanner"; 

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(
  <React.StrictMode>
      <Router>
        <Routes>
          <Route path="/" element={<App />} />
          <Route path="/form" element={<Form />} />
          <Route path="/scan" element={<CameraScanner />} /> 
        </Routes>
      </Router>
  </React.StrictMode>
);


reportWebVitals();
