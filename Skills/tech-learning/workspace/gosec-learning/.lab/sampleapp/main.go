package main

import (
	"crypto/md5"
	"database/sql"
	"fmt"
	"math/rand"
	"net/http"
	"os"
)

func main() {
	http.ListenAndServe(":8080", nil) // #nosec G114 -- demo suppression for teaching
	fmt.Println(md5.New())            //gosec:disable G401 -- demo suppression for weak hash
	fmt.Println(rand.Int())
	http.Get(os.Args[1])

	db, _ := sql.Open("sqlite3", "test.db")
	query := fmt.Sprintf("SELECT * FROM users WHERE id = %s", os.Args[2])
	db.Query(query)
}
