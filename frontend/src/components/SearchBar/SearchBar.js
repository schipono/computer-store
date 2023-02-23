import { ReactComponent as SearchIcon} from "../../assets/images/search.svg";
import './SearchBar.css';
import {DebounceInput} from "react-debounce-input";

function SearchBar({value, onChangeHandler, debounceTimeout}) {

  return (
    <div className="SearchBar">
      <div className="SearchBar__input_group">
        <SearchIcon className="SearchBar__search_icon"/>
        <DebounceInput className="SearchBar__input" type="text" debounceTimeout={debounceTimeout} placeholder="Search" value={value} onChange={onChangeHandler} />
      </div>
    </div>
  );
}


export default SearchBar;