#include "evas_common_private.h"
#include "evas_private.h"

#define MY_CLASS EVAS_3D_MESH_CLASS

static Evas_3D_Mesh_Frame *
evas_3d_mesh_frame_new(Evas_3D_Mesh *mesh)
{
   Evas_3D_Mesh_Frame *frame = NULL;
   frame = (Evas_3D_Mesh_Frame *)calloc(1, sizeof(Evas_3D_Mesh_Frame));

   if (frame == NULL)
     {
        ERR("Failed to allocate memory.");
        return NULL;
     }

   frame->mesh = mesh;
   evas_box3_empty_set(&frame->aabb);

   return frame;
}

static void
evas_3d_mesh_frame_free(Evas_3D_Mesh_Frame *frame)
{
   int i;

   if (frame->material)
     evas_3d_material_mesh_del(frame->material, frame->mesh);

   for (i = 0; i < EVAS_3D_VERTEX_ATTRIB_COUNT; i++)
     {
        if (frame->vertices[i].owns_data)
          free(frame->vertices[i].data);
     }

   free(frame);
}

Evas_3D_Mesh_Frame *
evas_3d_mesh_frame_find(Evas_3D_Mesh_Data *pd, int frame)
{
   Eina_List *l;
   Evas_3D_Mesh_Frame *f;

   EINA_LIST_FOREACH(pd->frames, l, f)
     {
        if (f->frame == frame)
          return f;
     }

   return NULL;
}

Eina_Bool
evas_3d_mesh_aabb_add_to_frame(Evas_3D_Mesh_Data *pd, int frame, int stride)
{
   Evas_3D_Mesh_Frame *curframe = evas_3d_mesh_frame_find(pd, frame);
   int i = 0, j = 0, step = 0, size = 0, max;
   float vxmin, vymin, vzmin, vxmax, vymax, vzmax;
   float *minmaxdata = NULL;
   Evas_Box3 box3;

   if (stride <= 0) return EINA_FALSE;

   if (!curframe)
     {
        ERR("Invalid frame %i.", frame);
        return EINA_FALSE;
     }

   step = curframe->vertices[EVAS_3D_VERTEX_POSITION].element_count;
   size = curframe->vertices[EVAS_3D_VERTEX_POSITION].size;
   minmaxdata = (float *)curframe->vertices[EVAS_3D_VERTEX_POSITION].data;

   if (!minmaxdata)
     {
        ERR("Invalid vertex data.");
        return EINA_FALSE;
     }

   vxmax = vxmin = minmaxdata[0];
   vymax = vymin = minmaxdata[1];
   vzmax = vzmin = minmaxdata[2];
   j += step;

   max = size / stride;
   for (i = 1; i < max; ++i)
     {
        vxmin > minmaxdata[j] ? vxmin = minmaxdata[j] : 0;
        vxmax < minmaxdata[j] ? vxmax = minmaxdata[j] : 0;
        vymin > minmaxdata[j + 1] ? vymin = minmaxdata[j + 1] : 0;
        vymax < minmaxdata[j + 1] ? vymax = minmaxdata[j + 1] : 0;
        vzmin > minmaxdata[j + 2] ? vzmin = minmaxdata[j + 2] : 0;
        vzmax < minmaxdata[j + 2] ? vzmax = minmaxdata[j + 2] : 0;
        j += step;
     }

   evas_box3_empty_set(&box3);
   evas_box3_set(&box3, vxmin, vymin, vzmin, vxmax, vymax, vzmax);
   curframe->aabb = box3;
   return EINA_TRUE;
}

static inline void
_mesh_init(Evas_3D_Mesh_Data *pd)
{
   pd->vertex_count = 0;
   pd->frame_count = 0;
   pd->frames = NULL;

   pd->index_format = EVAS_3D_INDEX_FORMAT_NONE;
   pd->index_count = 0;
   pd->indices = NULL;
   pd->owns_indices = EINA_FALSE;
   pd->assembly = EVAS_3D_VERTEX_ASSEMBLY_TRIANGLES;

   pd->nodes = NULL;
   pd->blend_sfactor = EVAS_3D_BLEND_ONE;
   pd->blend_dfactor = EVAS_3D_BLEND_ZERO;
   pd->blending = EINA_FALSE;
}

static inline void
_mesh_fini(Evas_3D_Mesh_Data *pd)
{
   Eina_List           *l;
   Evas_3D_Mesh_Frame  *f;

   if (pd->frames)
     {
        EINA_LIST_FOREACH(pd->frames, l, f)
          {
             evas_3d_mesh_frame_free(f);
          }

        eina_list_free(pd->frames);
     }

   if (pd->indices && pd->owns_indices)
     free(pd->indices);

   if (pd->nodes)
     eina_hash_free(pd->nodes);
}

static Eina_Bool
_mesh_node_geometry_change_notify(const Eina_Hash *hash EINA_UNUSED, const void *key,
                                  void *data EINA_UNUSED, void *fdata)
{
   Evas_3D_Node *n = *(Evas_3D_Node **)key;
   eo_do(n, evas_3d_object_change(EVAS_3D_STATE_NODE_MESH_GEOMETRY, (Evas_3D_Object *)fdata));
   return EINA_TRUE;
}

static Eina_Bool
_mesh_node_material_change_notify(const Eina_Hash *hash EINA_UNUSED, const void *key,
                                  void *data EINA_UNUSED, void *fdata)
{
   Evas_3D_Node *n = *(Evas_3D_Node **)key;
   eo_do(n, evas_3d_object_change(EVAS_3D_STATE_NODE_MESH_MATERIAL, (Evas_3D_Object *)fdata));
   return EINA_TRUE;
}

static void
_evas_3d_mesh_evas_3d_object_change_notify(Eo *obj, Evas_3D_Mesh_Data *pd, Evas_3D_State state, Evas_3D_Object *ref EINA_UNUSED)
{
   if (state == EVAS_3D_STATE_MESH_MATERIAL)
     {
        if (pd->nodes)
          eina_hash_foreach(pd->nodes, _mesh_node_material_change_notify, obj);
     }
   else
     {
        if (pd->nodes)
          eina_hash_foreach(pd->nodes, _mesh_node_geometry_change_notify, obj);
     }
}

EOLIAN static void
_evas_3d_mesh_evas_3d_object_update_notify(Eo *obj EINA_UNUSED, Evas_3D_Mesh_Data *pd)
{
   Eina_List *l;
   Evas_3D_Mesh_Frame *f;

   EINA_LIST_FOREACH(pd->frames, l, f)
     {
        if (f->material)
         {
            eo_do(f->material, evas_3d_object_update());
         }
     }
}


void
evas_3d_mesh_node_add(Evas_3D_Mesh *mesh, Evas_3D_Node *node)
{
   int count = 0;
   Evas_3D_Mesh_Data *pd = eo_data_scope_get(mesh, MY_CLASS);
   if (pd->nodes == NULL)
     {
        pd->nodes = eina_hash_pointer_new(NULL);

        if (pd->nodes == NULL)
          {
             ERR("Failed to create hash table.");
             return;
          }
     }
   else
     count = (int)(uintptr_t)eina_hash_find(pd->nodes, &node);

   eina_hash_set(pd->nodes, &node, (const void *)(uintptr_t)(count + 1));
}

void
evas_3d_mesh_node_del(Evas_3D_Mesh *mesh, Evas_3D_Node *node)
{
   int count = 0;
   Evas_3D_Mesh_Data *pd = eo_data_scope_get(mesh, MY_CLASS);
   if (pd->nodes == NULL)
     {
        ERR("No node to delete.");
        return;
     }

   count = (int)(uintptr_t)eina_hash_find(pd->nodes, &node);

   if (count == 1)
     eina_hash_del(pd->nodes, &node, NULL);
   else
     eina_hash_set(pd->nodes, &node, (const void *)(uintptr_t)(count - 1));
}


EAPI Evas_3D_Mesh *
evas_3d_mesh_add(Evas *e)
{
   MAGIC_CHECK(e, Evas, MAGIC_EVAS);
   return NULL;
   MAGIC_CHECK_END();
   Evas_Object *eo_obj = eo_add(MY_CLASS, e);
   return eo_obj;
}

EOLIAN static void
_evas_3d_mesh_eo_base_constructor(Eo *obj, Evas_3D_Mesh_Data *pd)
{
   eo_do_super(obj, MY_CLASS, eo_constructor());
   eo_do (obj, evas_3d_object_type_set(EVAS_3D_OBJECT_TYPE_MESH));
   _mesh_init(pd);
}

EOLIAN static void
_evas_3d_mesh_eo_base_destructor(Eo *obj, Evas_3D_Mesh_Data *pd)
{
   //evas_3d_object_unreference(&pd->base);
   _mesh_fini(pd);
   eo_do_super(obj, MY_CLASS, eo_destructor());
}

EOLIAN static void
_evas_3d_mesh_shade_mode_set(Eo *obj EINA_UNUSED, Evas_3D_Mesh_Data *pd, Evas_3D_Shade_Mode mode)
{
   if (pd->shade_mode != mode)
     {
        pd->shade_mode = mode;
        eo_do(obj, evas_3d_object_change(EVAS_3D_STATE_MESH_SHADE_MODE, NULL));
     }
}

EOLIAN static Evas_3D_Shade_Mode
_evas_3d_mesh_shade_mode_get(Eo *obj EINA_UNUSED, Evas_3D_Mesh_Data *pd)
{
   return pd->shade_mode;
}

EOLIAN static void
_evas_3d_mesh_vertex_count_set(Eo *obj, Evas_3D_Mesh_Data *pd, unsigned int count)
{
   pd->vertex_count = count;
   eo_do(obj, evas_3d_object_change(EVAS_3D_STATE_MESH_VERTEX_COUNT, NULL));
}

EOLIAN static int
_evas_3d_mesh_vertex_count_get(Eo *obj EINA_UNUSED, Evas_3D_Mesh_Data *pd)
{
   return pd->vertex_count;
}

EOLIAN static void
_evas_3d_mesh_frame_add(Eo *obj, Evas_3D_Mesh_Data *pd, int frame)
{
   Evas_3D_Mesh_Frame *f = evas_3d_mesh_frame_find(pd, frame);

   if (f != NULL)
     {
        ERR("Already existing frame.");
        return;
     }

   f = evas_3d_mesh_frame_new(obj);

   if (f == NULL)
     return;

   f->frame = frame;
   pd->frames = eina_list_append(pd->frames, f);
   eo_do(obj, evas_3d_object_change(EVAS_3D_STATE_MESH_FRAME, NULL));
}

EOLIAN static void
_evas_3d_mesh_frame_del(Eo *obj, Evas_3D_Mesh_Data *pd, int frame)
{
   Evas_3D_Mesh_Frame *f = evas_3d_mesh_frame_find(pd, frame);

   if (f == NULL)
     {
        ERR("Not existing mesh frame.");
        return;
     }

   pd->frames = eina_list_remove(pd->frames, f);
   evas_3d_mesh_frame_free(f);
   eo_do(obj, evas_3d_object_change(EVAS_3D_STATE_MESH_FRAME, NULL));
}

EOLIAN static void
_evas_3d_mesh_frame_material_set(Eo *obj, Evas_3D_Mesh_Data *pd, int frame, Evas_3D_Material *material)
{
   Evas_3D_Mesh_Frame *f = evas_3d_mesh_frame_find(pd, frame);

   if (f == NULL)
     {
        ERR("Not existing mesh frame.");
        return;
     }

   if (f->material == material)
     return;

   if (f->material)
     {
        evas_3d_material_mesh_del(f->material, obj);
        eo_unref(f->material);
     }

   f->material = material;
   eo_ref(material);
   eo_do(obj, evas_3d_object_change(EVAS_3D_STATE_MESH_MATERIAL, NULL));
   evas_3d_material_mesh_add(material, obj);
}

EOLIAN static Evas_3D_Material *
_evas_3d_mesh_frame_material_get(Eo *obj EINA_UNUSED, Evas_3D_Mesh_Data *pd, int frame)
{
   Evas_3D_Mesh_Frame *f = evas_3d_mesh_frame_find(pd, frame);

   if (f == NULL)
     {
        ERR("Not existing mesh frame.");
        return NULL;
     }

   return f->material;
}

EOLIAN static void
_evas_3d_mesh_frame_vertex_data_set(Eo *obj, Evas_3D_Mesh_Data *pd, int frame, Evas_3D_Vertex_Attrib attrib, int stride, const void *data)
{
   Evas_3D_Mesh_Frame *f = evas_3d_mesh_frame_find(pd, frame);
   int element_count;

   if (f == NULL)
     {
        ERR("Not existing mesh frame.");
        return;
     }

   if (stride < (int)sizeof(float))
     {
        ERR("Stride too small");
        return;
     }

   if (attrib == EVAS_3D_VERTEX_POSITION)
     {
        int i = 0, j = 0, size = stride/sizeof(float);
        float vxmin, vymin, vzmin, vxmax, vymax, vzmax;
        float *minmaxdata = (float *)data;
        Evas_Box3 box3;

        element_count = 3;

        if (minmaxdata)
          {
             vxmax = vxmin = minmaxdata[0];
             vymax = vymin = minmaxdata[1];
             vzmax = vzmin = minmaxdata[2];
             j += size;

             for (i = 1; i < size; ++i)
               {
                  vxmin > minmaxdata[j] ? vxmin = minmaxdata[j] : 0;
                  vxmax < minmaxdata[j] ? vxmax = minmaxdata[j] : 0;
                  vymin > minmaxdata[j + 1] ? vymin = minmaxdata[j + 1] : 0;
                  vymax < minmaxdata[j + 1] ? vymax = minmaxdata[j + 1] : 0;
                  vzmin > minmaxdata[j + 2] ? vzmin = minmaxdata[j + 2] : 0;
                  vzmax < minmaxdata[j + 2] ? vzmax = minmaxdata[j + 2] : 0;
                  j += size;
                }

              evas_box3_empty_set(&box3);
              evas_box3_set(&box3, vxmin, vymin, vzmin, vxmax, vymax, vzmax);
              f->aabb = box3;
          }
        else
          {
             ERR("Axis-Aligned Bounding Box wasn't added in frame %d ", frame);
          }
     }
   else if (attrib == EVAS_3D_VERTEX_NORMAL)
     {
        element_count = 3;
     }
   else if (attrib == EVAS_3D_VERTEX_TANGENT)
     {
        element_count = 3;
     }
   else if (attrib == EVAS_3D_VERTEX_COLOR)
     {
        element_count = 4;
     }
   else if (attrib == EVAS_3D_VERTEX_TEXCOORD)
     {
        element_count = 2;
     }
   else
     {
        ERR("Invalid vertex attrib.");
        return;
     }

   if (f->vertices[attrib].owns_data && f->vertices[attrib].data)
     free(f->vertices[attrib].data);

   f->vertices[attrib].size = 0;
   f->vertices[attrib].stride = stride;
   f->vertices[attrib].data = (void *)data;
   f->vertices[attrib].owns_data = EINA_FALSE;
   f->vertices[attrib].element_count = element_count;

   eo_do(obj, evas_3d_object_change(EVAS_3D_STATE_MESH_VERTEX_DATA, NULL));
}

EOLIAN static void
_evas_3d_mesh_frame_vertex_data_copy_set(Eo *obj, Evas_3D_Mesh_Data *pd, int frame, Evas_3D_Vertex_Attrib attrib, int stride, const void *data)
{
   Evas_3D_Mesh_Frame *f = evas_3d_mesh_frame_find(pd, frame);
   Evas_3D_Vertex_Buffer *vb;
   int size, element_count;

   if (f == NULL)
     {
        ERR("Not existing mesh frame.");
        return;
     }

   if (attrib == EVAS_3D_VERTEX_POSITION)
     {
        element_count = 3;
     }
   else if (attrib == EVAS_3D_VERTEX_NORMAL)
     {
        element_count = 3;
     }
   else if (attrib == EVAS_3D_VERTEX_TANGENT)
     {
        element_count = 3;
     }
   else if (attrib == EVAS_3D_VERTEX_COLOR)
     {
        element_count = 4;
     }
   else if (attrib == EVAS_3D_VERTEX_TEXCOORD)
     {
        element_count = 2;
     }
   else
     {
        ERR("Invalid vertex attrib.");
        return;
     }

   vb = &f->vertices[attrib];
   size = element_count * sizeof(float) * pd->vertex_count;

   if (!vb->owns_data || vb->size < size)
     {
        if (vb->owns_data && vb->data)
          free(vb->data);

        vb->data = malloc(size);

        if (vb->data == NULL)
          {
             vb->element_count = 0;
             vb->size = 0;
             vb->stride = 0;
             vb->owns_data = EINA_FALSE;

             ERR("Failed to allocate memory.");
             return;
          }

        vb->size = size;
        vb->owns_data = EINA_TRUE;
     }

   vb->element_count = element_count;
   vb->stride = 0;

   if (data == NULL)
     return;

   if (stride == 0 || stride == (int)(element_count * sizeof(float)))
     {
        memcpy(vb->data, data, size);
     }
   else
     {
        int    i;
        float *dst = (float *)vb->data;
        float *src = (float *)data;

        if (element_count == 2)
          {
             for (i = 0; i <pd->vertex_count; i++)
               {
                  *dst++ = src[0];
                  *dst++ = src[1];

                  src = (float *)((char *)src + stride);
               }
          }
        else if (element_count == 3)
          {
             for (i = 0; i <pd->vertex_count; i++)
               {
                  *dst++ = src[0];
                  *dst++ = src[1];
                  *dst++ = src[2];

                  src = (float *)((char *)src + stride);
               }
          }
        else if (element_count == 4)
          {
             for (i = 0; i <pd->vertex_count; i++)
               {
                  *dst++ = src[0];
                  *dst++ = src[1];
                  *dst++ = src[2];
                  *dst++ = src[3];

                  src = (float *)((char *)src + stride);
               }
          }
     }

   if (attrib == EVAS_3D_VERTEX_POSITION &&
       !evas_3d_mesh_aabb_add_to_frame(pd, frame, stride))
     {
        ERR("Axis-Aligned Bounding Box wasn't added in frame %d ", frame);
     }

   eo_do(obj, evas_3d_object_change(EVAS_3D_STATE_MESH_VERTEX_DATA, NULL));
}

EOLIAN static void *
_evas_3d_mesh_frame_vertex_data_map(Eo *obj EINA_UNUSED, Evas_3D_Mesh_Data *pd, int frame, Evas_3D_Vertex_Attrib attrib)
{
   Evas_3D_Mesh_Frame *f = evas_3d_mesh_frame_find(pd, frame);

   if (f == NULL)
     {
        ERR("Not existing mesh frame.");
        return NULL;
     }

   if (f->vertices[attrib].mapped)
     {
        ERR("Try to map alreadly mapped data.");
        return NULL;
     }

   f->vertices[attrib].mapped = EINA_TRUE;
   return f->vertices[attrib].data;
}

EOLIAN static void
_evas_3d_mesh_frame_vertex_data_unmap(Eo *obj EINA_UNUSED, Evas_3D_Mesh_Data *pd, int frame, Evas_3D_Vertex_Attrib attrib)
{
   Evas_3D_Mesh_Frame *f = evas_3d_mesh_frame_find(pd, frame);

   if (f == NULL)
     {
        ERR("Not existing mesh frame.");
        return;
     }

   if (!f->vertices[attrib].mapped)
     {
        ERR("Try to unmap data which is not mapped yet.");
        return;
     }

   f->vertices[attrib].mapped = EINA_FALSE;
}

EOLIAN static int
_evas_3d_mesh_frame_vertex_stride_get(Eo *obj EINA_UNUSED, Evas_3D_Mesh_Data *pd, int frame, Evas_3D_Vertex_Attrib attrib)
{
   Evas_3D_Mesh_Frame *f = evas_3d_mesh_frame_find(pd, frame);

   if (f == NULL)
     {
        ERR("Not existing mesh frame.");
        return 0;
     }

   return f->vertices[attrib].stride;
}

EOLIAN static void
_evas_3d_mesh_index_data_set(Eo *obj, Evas_3D_Mesh_Data *pd, Evas_3D_Index_Format format, int count, const void *indices)
{
   if (pd->owns_indices && pd->indices)
     free(pd->indices);

   pd->index_format = format;
   pd->index_count = count;
   pd->index_size = 0;
   pd->indices = (void *)indices;
   pd->owns_indices = EINA_FALSE;

   eo_do(obj, evas_3d_object_change(EVAS_3D_STATE_MESH_INDEX_DATA, NULL));
}

EOLIAN static void
_evas_3d_mesh_index_data_copy_set(Eo *obj EINA_UNUSED, Evas_3D_Mesh_Data *pd, Evas_3D_Index_Format format, int count, const void *indices)
{
   int size;

   if (format == EVAS_3D_INDEX_FORMAT_UNSIGNED_BYTE)
     {
        size = count * sizeof(unsigned char);
     }
   else if (format == EVAS_3D_INDEX_FORMAT_UNSIGNED_SHORT)
     {
        size = count * sizeof(unsigned short);
     }
   else
     {
        ERR("Invalid index format.");
        return;
     }

   if (!pd->owns_indices || pd->index_size < size)
     {
        if (pd->owns_indices && pd->indices)
          free(pd->indices);

        pd->indices = malloc(size);

        if (pd->indices == NULL)
          {
             ERR("Failed to allocate memory.");
             return;
          }

        pd->index_size = size;
        pd->owns_indices = EINA_TRUE;
     }

   pd->index_format = format;
   pd->index_count = count;

   if (indices)
     memcpy(pd->indices, indices, size);
}

EOLIAN static Evas_3D_Index_Format
_evas_3d_mesh_index_format_get(Eo *obj EINA_UNUSED, Evas_3D_Mesh_Data *pd)
{
   return pd->index_format;
}

EOLIAN static int
_evas_3d_mesh_index_count_get(Eo *obj EINA_UNUSED, Evas_3D_Mesh_Data *pd)
{
   return pd->index_count;
}

EOLIAN static void *
_evas_3d_mesh_index_data_map(Eo *obj EINA_UNUSED, Evas_3D_Mesh_Data *pd)
{
   if (pd->index_mapped)
     {
        ERR("Try to map alreadly mapped data.");
        return NULL;
     }

   pd->index_mapped = EINA_TRUE;
   return pd->indices;
}

EOLIAN static void
_evas_3d_mesh_index_data_unmap(Eo *obj EINA_UNUSED, Evas_3D_Mesh_Data *pd)
{
   if (!pd->index_mapped)
     {
        ERR("Try to unmap data which is not mapped yet.");
        return;
     }

   pd->index_mapped = EINA_FALSE;
}

EOLIAN static void
_evas_3d_mesh_vertex_assembly_set(Eo *obj, Evas_3D_Mesh_Data *pd, Evas_3D_Vertex_Assembly assembly)
{
   pd->assembly = assembly;
   eo_do(obj, evas_3d_object_change(EVAS_3D_STATE_MESH_VERTEX_ASSEMBLY, NULL));
}

EOLIAN static Evas_3D_Vertex_Assembly
_evas_3d_mesh_vertex_assembly_get(Eo *obj EINA_UNUSED, Evas_3D_Mesh_Data *pd)
{
   return pd->assembly;
}

EOLIAN static void
_evas_3d_mesh_fog_color_set(Eo *obj, Evas_3D_Mesh_Data *pd, Evas_Real r, Evas_Real g, Evas_Real b, Evas_Real a)
{
   evas_color_set(&pd->fog_color, r, g, b, a);
   eo_do(obj, evas_3d_object_change(EVAS_3D_STATE_MESH_FOG, NULL));
}

EOLIAN static void
_evas_3d_mesh_fog_color_get(Eo *obj EINA_UNUSED, Evas_3D_Mesh_Data *pd,
                                   Evas_Real *r, Evas_Real *g, Evas_Real *b, Evas_Real *a)
{
   if (r) *r = pd->fog_color.r;
   if (g) *g = pd->fog_color.g;
   if (b) *b = pd->fog_color.b;
   if (a) *a = pd->fog_color.a;
}

EOLIAN static void
_evas_3d_mesh_fog_enable_set(Eo *obj, Evas_3D_Mesh_Data *pd, Eina_Bool enabled)
{
   pd->fog_enabled = enabled;
   eo_do(obj, evas_3d_object_change(EVAS_3D_STATE_MESH_FOG, NULL));
}

EOLIAN static Eina_Bool
_evas_3d_mesh_fog_enable_get(Eo *obj EINA_UNUSED, Evas_3D_Mesh_Data *pd)
{
   return pd->fog_enabled;
}

EOLIAN static void
_evas_3d_mesh_blending_enable_set(Eo *obj, Evas_3D_Mesh_Data *pd, Eina_Bool blending)
{
   pd->blending = blending;
   eo_do(obj, evas_3d_object_change(EVAS_3D_STATE_MESH_BLENDING, NULL));
}

EOLIAN static Eina_Bool
_evas_3d_mesh_blending_enable_get(Eo *obj EINA_UNUSED, Evas_3D_Mesh_Data *pd)
{
   return pd->blending;
}

EOLIAN static void
_evas_3d_mesh_blending_func_set(Eo *obj, Evas_3D_Mesh_Data *pd, Evas_3D_Blend_Func sfactor, Evas_3D_Blend_Func dfactor)
{
   pd->blend_sfactor = sfactor;
   pd->blend_dfactor = dfactor;
   eo_do(obj, evas_3d_object_change(EVAS_3D_STATE_MESH_BLENDING, NULL));
}

EOLIAN static void
_evas_3d_mesh_blending_func_get(Eo *obj EINA_UNUSED, Evas_3D_Mesh_Data *pd,
                                   Evas_3D_Blend_Func *sfactor, Evas_3D_Blend_Func *dfactor)
{
   if (sfactor) *sfactor = pd->blend_sfactor;
   if (dfactor) *dfactor = pd->blend_dfactor;
}

EOLIAN static void
_evas_3d_mesh_file_set(Eo *obj, Evas_3D_Mesh_Data *pd, Evas_3D_Mesh_File_Type type, const char *file, const char *key EINA_UNUSED)
{
   _mesh_fini(pd);
   _mesh_init(pd);

   if (file == NULL) return;

   evas_common_load_model_to_file(obj, file, type);
}

EOLIAN static void
_evas_3d_mesh_save(Eo *obj, Evas_3D_Mesh_Data *pd, Evas_3D_Mesh_File_Type type,
                   const char *file, const char *key EINA_UNUSED)
{
   if ((file == NULL) || (obj == NULL) || (pd == NULL)) return;

   Evas_3D_Mesh_Frame *f = evas_3d_mesh_frame_find(pd, 0);

   if (f == NULL)
     {
        ERR("Not existing mesh frame.");
        return;
     }

   evas_common_save_model_to_file(obj, file, f, type);
}

static inline void
_mesh_frame_find(Evas_3D_Mesh_Data *mesh, int frame,
                 Eina_List **l, Eina_List **r)
{
   Eina_List *left, *right;
   Evas_3D_Mesh_Frame *f0 = NULL, *f1;

   left = mesh->frames;
   right = eina_list_next(left);

   while (right)
     {
        f0 = (Evas_3D_Mesh_Frame *)eina_list_data_get(left);
        f1 = (Evas_3D_Mesh_Frame *)eina_list_data_get(right);

        if (frame >= f0->frame && frame <= f1->frame)
          break;

        left = right;
        right = eina_list_next(left);
     }

   if (right == NULL)
     {
        if (f0 && frame <= f0->frame)
          {
             *l = NULL;
             *r = left;
          }
        else
          {
             *l = left;
             *r = NULL;
          }
     }

   *l = left;
   *r = right;
}

void
evas_3d_mesh_interpolate_vertex_buffer_get(Evas_3D_Mesh *mesh, int frame,
                                           Evas_3D_Vertex_Attrib  attrib,
                                           Evas_3D_Vertex_Buffer *buf0,
                                           Evas_3D_Vertex_Buffer *buf1,
                                           Evas_Real             *weight)
{
   Eina_List *l, *r;
   const Evas_3D_Mesh_Frame *f0 = NULL, *f1 = NULL;
   Evas_3D_Mesh_Data *pd = eo_data_scope_get(mesh, MY_CLASS);
   _mesh_frame_find(pd, frame, &l, &r);

   while (l)
     {
        f0 = (const Evas_3D_Mesh_Frame *)eina_list_data_get(l);

        if (f0->vertices[attrib].data != NULL)
          break;

        l = eina_list_prev(l);
        f0 = NULL;
     }

   while (r)
     {
        f1 = (const Evas_3D_Mesh_Frame *)eina_list_data_get(r);

        if (f1->vertices[attrib].data != NULL)
          break;

        r = eina_list_next(r);
        f1 = NULL;
     }

   if (f0 == NULL && f1 == NULL)
     return;

   if (f0 == NULL)
     {
        f0 = f1;
     }
   else if (f1 != NULL)
     {
        if (frame == f0->frame)
          {
             f1 = NULL;
          }
        else if (frame == f1->frame)
          {
             f0 = f1;
             f1 = NULL;
          }
     }

   buf0->data = f0->vertices[attrib].data;
   buf0->stride = f0->vertices[attrib].stride;
   buf0->size = f0->vertices[attrib].size;

   if (f1)
     {
        buf1->data = f1->vertices[attrib].data;
        buf1->stride = f1->vertices[attrib].stride;
        buf1->size = f1->vertices[attrib].size;

        *weight = (f1->frame - frame) / (Evas_Real)(f1->frame - f0->frame);
     }
   else
     {
        buf1->data = NULL;
        buf1->stride = 0;
        buf1->size = 0;

        *weight = 1.0;
     }
}

#include "canvas/evas_3d_mesh.eo.c"
