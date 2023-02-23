import './ComputerGrid.css';
import DisplayCard from "../DisplayCard/DisplayCard";

function ComputerGrid({ computers, loadMoreHandler, moreToLoad }) {
  return (
    <div className="ComputerGrid">
      <div className="ComputerGrid__display_cards">
        {(computers.length !== 0) && computers.map(item => <DisplayCard key={item.id} computer={item} />)}
      </div>
      {moreToLoad &&
        <>
          <div className="ComputerGrid__show_more">
            <button className="ComputerGrid__show_more_button" onClick={loadMoreHandler}>Show more</button>
          </div>
        </>
      }

    </div>

  );
}

export default ComputerGrid;