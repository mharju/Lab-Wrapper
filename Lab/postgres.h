//
//  postgres.h
//  Lab
//
//  Created by Mikko Harju on 10.4.2021.
//  Copyright © 2021 Mikko Harju. All rights reserved.
//

#ifndef postgres_h
#define postgres_h
#include <libpq-fe.h>
#include "bencode.h"

typedef struct {
    const char *conninfo;
    PGconn *conn;
} connection_t;

connection_t* pg_connect(const char* conninfo, size_t info_len);
void pg_finish(connection_t *conn);
struct bencode* pg_query(const connection_t* conn, const char* query);

#endif /* postgres_h */
