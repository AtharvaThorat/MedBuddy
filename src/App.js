import { Component } from 'react';
import { Link } from 'react-router-dom';
import './App.css';
import call from './call.png';
import document from './document.png';
import homePageLogo from './homePage.png';
import medScan from './medScann.png';
import records from './reminderHistory.png';

class App extends Component{
  
  render(){
    return (
      <div className="App">
        <img className="home_page_logo" src={homePageLogo} alt="Home Page Logo" />
        <div className="container2">
          <div className='inner_container'>
            <div className='inner_logos_div'>
               {/* Navigate to Camera Scanner when clicked */}
               <Link to="/scan">
                <img className="inner_logos" src={medScan} alt="Medicine Scan" />
              </Link>
            </div>
            <div >
              <Link to="/form" className='inner_logos_div'> 
                <img className="inner_logos" src={document} alt="Document" />
              </Link>
            </div>
          </div>
          <div className='inner_container'>
            <div className='inner_logos_div'>
                <img className="inner_logos" src={records} alt="Records" />
            </div>
            <div className='inner_logos_div'>
              <img className="inner_logos" src={call} alt="Call" />
            </div>
          </div>
        </div>
      </div>
    );
  }
}

export default App;
