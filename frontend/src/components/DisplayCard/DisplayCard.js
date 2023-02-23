import { ReactComponent as FreeShipping } from '../../assets/images/free_shipping.svg';
import { ReactComponent as FreeGift } from '../../assets/images/free_gift.svg';
import './DisplayCard.css';

const DisplayCard = ({computer}) => {
  return (
    <div className="DisplayCard">
      <div className="DisplayCard__image">
        <div className="DisplayCard__image_bounds">
          <img src={computer.image} />
        </div>
      </div>
      <div className="DisplayCard__non_image_content">
        <div className="DisplayCard__vendor">
          {computer.vendor}
        </div>
        <div className="DisplayCard__title">
          {computer.title}
        </div>
        <div className="DisplayCard__pricing">
          {computer.strikedPrice !== null
            ? (<><span className="DisplayCard__sale_price">${computer.price}</span> <span className="DisplayCard__original_price"><s>${computer.strikedPrice}</s></span></>)
            : (<span className="DisplayCard__price">${computer.price}</span>)
          }
        </div>
        <hr />
        <div className="DisplayCard__incentives">
          <FreeShipping />
          <span>Free Shipping</span>
          <FreeGift />
          <span>Free Gift</span>
        </div>
        <button className="DisplayCard__view_deal_button">VIEW DEAL</button>
      </div>
    </div>
  );
};


export default DisplayCard;