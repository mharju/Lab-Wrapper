//
//  postgres.c
//  Lab
//
//  Created by Mikko Harju on 10.4.2021.
//  Copyright © 2021 Mikko Harju. All rights reserved.
//

#include "postgres.h"
#include <stdlib.h>
#include <string.h>
#include <wchar.h>

static char rfc3986[256] = {0};
static char html5[256] = {0};

// from https://stackoverflow.com/questions/5842471/c-url-encoding
static void url_encoder_rfc_tables_init() {
    int i;

    for (i = 0; i < 256; i++){
        rfc3986[i] = isalnum( i) || i == '~' || i == '-' || i == '.' || i == '_' ? i : 0;
        html5[i] = isalnum( i) || i == '*' || i == '-' || i == '.' || i == '_' ? i : (i == ' ') ? '+' : 0;
    }
}

static char *url_encode( char *table, char *s, char *enc){

    for (; *s; s++){

        if (table[*s]) sprintf( enc, "%c", table[*s]);
        else sprintf( enc, "%%%02X", (uint8_t)*s);
        while (*++enc);
    }

    return( enc);
}

connection_t* pg_connect(const char* conninfo, size_t info_len) {
    connection_t *conn = (connection_t*) malloc(sizeof(connection_t));
    conn->conn = PQconnectdb(conninfo);
    conn->conninfo = (const char*)malloc(info_len * sizeof(char));
    strncpy((char*)conn->conninfo, conninfo, info_len);
    if (PQstatus(conn->conn) != CONNECTION_OK)
    {
        fprintf(stderr, "Connection to database failed: %s",
                PQerrorMessage(conn->conn));
        return NULL;
    }
    return conn;
}

void pg_finish(connection_t *conn) {
    PQfinish(conn->conn);
    free((void*)conn->conninfo);
    free(conn);
}

struct bencode* pg_query(const connection_t* conn, const char* query) {
    PGresult   *res;
    int         nFields;
    
    url_encoder_rfc_tables_init();

    res = PQexec(conn->conn, query);
    struct bencode *result = ben_dict();
    struct bencode *results = ben_list();
    ben_dict_set(result, ben_str("rows"), results);

    nFields = PQnfields(res);
    for (int i = 0; i < PQntuples(res); i++)
    {
        struct bencode *row = ben_list();
        for (int j = 0; j < nFields; j++) {
            char encoded[4096] = {0};
            url_encode(rfc3986, PQgetvalue(res, i, j), encoded);
            ben_list_append(row, ben_str(encoded));
        }
        ben_list_append(results, row);
    }
    PQclear(res);
    
    return result;
}
