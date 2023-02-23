import './ResultsReport.css';

function ResultsReport({ displayedCount, totalCount }) {

  return (
    <div className="ResultsReport">
      <h1>Results</h1>
      {displayedCount === 0 && totalCount === 0
        ? <span>No results found</span>
        : <span>Showing {displayedCount} of {totalCount}</span>
      }
    </div>
  );
}

export default ResultsReport;