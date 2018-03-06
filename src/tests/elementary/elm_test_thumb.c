#ifdef HAVE_CONFIG_H
# include "elementary_config.h"
#endif

#define EFL_ACCESS_BETA
#include <Elementary.h>
#include "elm_suite.h"

START_TEST (elm_thumb_legacy_type_check)
{
   Evas_Object *win, *thumb;
   const char *type;

   char *args[] = { "exe" };
   elm_init(1, args);
   win = elm_win_add(NULL, "thumb", ELM_WIN_BASIC);

   thumb = elm_thumb_add(win);

   type = elm_object_widget_type_get(thumb);
   ck_assert(type != NULL);
   ck_assert(!strcmp(type, "Elm_Thumb"));

   /* It had abnormal object type... */
   type = evas_object_type_get(thumb);
   ck_assert(type != NULL);
   ck_assert(!strcmp(type, "Elm_Thumb"));

   elm_shutdown();
}
END_TEST

START_TEST (elm_atspi_role_get)
{
   Evas_Object *win, *thumb;
   Efl_Access_Role role;

   char *args[] = { "exe" };
   elm_init(1, args);
   win = elm_win_add(NULL, "thumb", ELM_WIN_BASIC);

   thumb = elm_thumb_add(win);
   role = efl_access_role_get(thumb);

   ck_assert(role == EFL_ACCESS_ROLE_IMAGE);

   elm_shutdown();
}
END_TEST

void elm_test_thumb(TCase *tc)
{
   tcase_add_test(tc, elm_thumb_legacy_type_check);
   tcase_add_test(tc, elm_atspi_role_get);
}
