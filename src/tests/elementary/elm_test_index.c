#ifdef HAVE_CONFIG_H
# include "elementary_config.h"
#endif

#define EFL_ACCESS_BETA
#include <Elementary.h>
#include "elm_suite.h"

START_TEST (elm_index_legacy_type_check)
{
   Evas_Object *win, *index;
   const char *type;

   char *args[] = { "exe" };
   elm_init(1, args);
   win = elm_win_add(NULL, "index", ELM_WIN_BASIC);

   index = elm_index_add(win);

   type = elm_object_widget_type_get(index);
   ck_assert(type != NULL);
   ck_assert(!strcmp(type, "Elm_Index"));

   type = evas_object_type_get(index);
   ck_assert(type != NULL);
   ck_assert(!strcmp(type, "elm_index"));

   elm_shutdown();
}
END_TEST

START_TEST (elm_atspi_role_get)
{
   Evas_Object *win, *idx;
   Efl_Access_Role role;

   char *args[] = { "exe" };
   elm_init(1, args);
   win = elm_win_add(NULL, "index", ELM_WIN_BASIC);

   idx = elm_index_add(win);
   role = efl_access_role_get(idx);

   ck_assert(role == EFL_ACCESS_ROLE_SCROLL_BAR);

   elm_shutdown();
}
END_TEST

void elm_test_index(TCase *tc)
{
   tcase_add_test(tc, elm_index_legacy_type_check);
   tcase_add_test(tc, elm_atspi_role_get);
}
