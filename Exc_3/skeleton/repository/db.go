package repository

import (
	"ordersystem/model"
	"time"
)

type DatabaseHandler struct {
	// drinks represent all available drinks
	drinks []model.Drink
	// orders serves as order history
	orders []model.Order
}

// todo
func NewDatabaseHandler() *DatabaseHandler {

	drinks := []model.Drink{
		{ID: 1, Name: "Water", Price: 1.5, Description: "Still mineral water"},
		{ID: 2, Name: "Beer", Price: 3.5, Description: "Local draft beer"},
		{ID: 3, Name: "Wine", Price: 5.0, Description: "Red wine from local vineyard"},
	}

	orders := []model.Order{
		{DrinkID: 1, CreatedAt: time.Now(), Amount: 2},
		{DrinkID: 2, CreatedAt: time.Now(), Amount: 1},
	}

	return &DatabaseHandler{
		drinks: drinks,
		orders: orders,
	}
}

func (db *DatabaseHandler) GetDrinks() []model.Drink {
	return db.drinks
}

func (db *DatabaseHandler) GetOrders() []model.Order {
	return db.orders
}

// todo
func (db *DatabaseHandler) GetTotalledOrders() map[uint64]uint64 {
	totalledOrders := make(map[uint64]uint64) // Initializes the map and iterates through all orders to accumulate the total amount per drink ID
	for _, order := range db.orders {
		totalledOrders[order.DrinkID] += uint64(order.Amount)
	}
	return totalledOrders
}

func (db *DatabaseHandler) AddOrder(order *model.Order) {
	// todo
	// add order to db.orders slice
	db.orders = append(db.orders, *order)
}
