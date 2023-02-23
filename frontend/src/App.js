import { useState, useEffect, useCallback } from 'react';
import './App.css';
import axios from 'axios';
import SearchBar from "./components/SearchBar/SearchBar";
import ResultsReport from "./components/ResultsReport/ResultsReport";
import ComputerGrid from "./components/ComputerGrid/ComputerGrid";

const API_URL = process.env.NODE_ENV === 'production' ? '' : process.env.REACT_APP_API_URL

function App() {
  const [ computers, setComputers ] = useState([]);
  const [ totalCount, setTotalCount ] = useState(0);
  const [ searchTerm, setSearchTerm ] = useState('');
  const [ pageIndex, setPageIndex ] = useState(1);
  const [ moreToLoad, setMoreToLoad ] = useState(false);

  // Build api URL from state
  const searchParam = searchTerm ? `search=${encodeURIComponent(searchTerm)}` : '';
  const pageParam = pageIndex > 1 ? `page=${pageIndex}` : '';
  const startQueryString = (searchParam || pageParam) ? '?' : '';
  const multiParam = (searchParam && pageParam) ? '&' : '';
  const queryString = startQueryString + searchParam + multiParam + pageParam;
  const url = `${API_URL}/api/v1/computers/${queryString}`

  const getSearchResults = useCallback(async () => {
    try {
      const searchResults = await axios.get(url);
      if (pageIndex === 1) {
        setComputers(searchResults.data.results)
      } else {
        setComputers(c => [...c, ...searchResults.data.results])
      }
      setTotalCount(searchResults.data.count)
      setMoreToLoad(searchResults.data.next !== null)
    } catch (err) {
      console.log('Failed to fetch response from url:', url)
    }
  }, [url, pageIndex]);

  useEffect(() => {
    getSearchResults();
  }, [searchTerm, pageIndex, getSearchResults])

  const handleInputChange = (e) => {
    setPageIndex(1)
    setSearchTerm(e.target.value)
  }

  const handleLoadMore = (e) => {
    setPageIndex(pi => pi + 1)
  }

  return (
    <div className="App">
      <SearchBar value={searchTerm} onChangeHandler={handleInputChange} debounceTimeout={250}/>
      <ResultsReport displayedCount={computers.length} totalCount={totalCount} />
      <ComputerGrid computers={computers} loadMoreHandler={handleLoadMore} moreToLoad={moreToLoad} />
    </div>
  );
}

export default App;
