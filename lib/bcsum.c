#include <sqlite3ext.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
SQLITE_EXTENSION_INIT1

#ifdef _WIN32
__declspec(dllexport)
#endif

typedef struct BCSumNode {
   struct BCSumNode* next;
   int value;
   char* order;
} BCSumNode;

int bcsum_cmp_node(BCSumNode* a, BCSumNode* b) {
   int result;

   if ((result = strcmp(a->order, b->order)) != 0) {
      // Ascending
      return result;
   } else {
      // Descending
      return b->value - a->value;
   }
}

void bcsum_step(sqlite3_context *context, int argc, sqlite3_value **argv) {
   BCSumNode* head, * new, * curr, * prev;
   int t1, t2;

   head = (BCSumNode*)sqlite3_aggregate_context(context, sizeof(*head));
   t1 = sqlite3_value_numeric_type(argv[0]);
   t2 = sqlite3_value_type(argv[1]);

   if (t1 != SQLITE_NULL && t2 != SQLITE_NULL) {
      new = malloc(sizeof(*new));
      new->value = sqlite3_value_int(argv[0]);
      new->order = strdup((char*)sqlite3_value_text(argv[1]));
      new->next = NULL;

      // Insert the node in the right order
      if (head->next == NULL) {
         head->next = new;
      } else {
         prev = head;
         curr = prev->next;
         while (curr != NULL && bcsum_cmp_node(curr, new) < 0) {
            prev = curr;
            curr = curr->next;
         }
         prev->next = new;
         new->next = curr;
      }
   }
}

void bcsum_finalize(sqlite3_context *context) {
   BCSumNode* head, * curr, * tmp;
   int bcsum;

   head = sqlite3_aggregate_context(context, sizeof(*head));

   bcsum = 0;
   curr = head->next;
   while (curr != NULL) {
      bcsum += curr->value;
      if (bcsum < 0) bcsum = 0;

      tmp = curr;
      curr = curr->next;
      free(tmp->order);
      free(tmp);
   }

   sqlite3_result_int(context, bcsum);
}

int sqlite3_extension_init(
   sqlite3 *db,
   char **pzErrMsg,
   const sqlite3_api_routines *pApi
){
   int rc = SQLITE_OK;
   SQLITE_EXTENSION_INIT2(pApi);
   sqlite3_create_function(db, "bcsum", 2, SQLITE_UTF8, 0,
         0, bcsum_step, bcsum_finalize);
   return rc;
}
