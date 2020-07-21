#pragma once

#include <cairo.h>
#include <cairo-svg.h>
#include <iostream>
#include <nlohmann/json.hpp>
#include <map>
#include <pango/pangocairo.h>
#include <tuple>
#include <string>
#include <type_traits>

#include "architecture.h"
#include "likwid_defines.hpp"

using json = nlohmann::json;

// ----- simple color type ----- //
typedef std::tuple<double, double, double> rgb_color;

enum label_position {
  INSIDE, BOTTOM, LEFT
};

class saturation_diagram {
  public:
    /* ======== Primary functions ======== 
     * These are the high-level functions intended primarily for use outside 
     * this class. Intended usage is demonstrated in fhv.cpp::visualize.
     */
    /* ---- test color lerp ----
     * Draws a swatch of a gradient calculated using color_lerp to test before
     * using in a saturation diagram
     */
    static void test_color_lerp(
      rgb_color min_color, 
      rgb_color max_color,
      unsigned width,
      unsigned height,
      unsigned num_steps);

    /* ---- calculate saturation colors ----- 
     * The return value of this function is intended to be passed to
     * draw_diagram. 
     */ 
    static std::map<std::string, rgb_color>
    calculate_saturation_colors(
      json region_saturation,
      rgb_color min_color,
      rgb_color max_color);

    /* ---- draw diagram ----
     * the function that actually makes the diagram 
     */
    static void draw_diagram(
      std::map<std::string, rgb_color> region_colors,
      json region_data,
      rgb_color min_color,
      rgb_color max_color,
      std::string region_name,
      std::string parameters,
      std::string output_filename);


    /* ======== Helper functions: general ======== 
     * These may be used elsewhere but are intended for internal use. They
     * include things like clamping and scaling values that are applied before
     * calculating colors.
     */
    /* ----- LINEAR INTERPOLATION (LERP) ----- 
     * Used to create a gradient from min_color to max_color. This will be used
     * to indicate saturation.
     *
     * taken from
     * https://en.wikipedia.org/wiki/Linear_interpolation#Programming_language_support
     *
     * used under Creative Commons Attribution-ShareAlike 3.0 Unported License. See
     * https://en.wikipedia.org/wiki/Wikipedia:Text_of_Creative_Commons_Attribution-ShareAlike_3.0_Unported_License
     * for full text
     *
     * Imprecise method, which does not guarantee result = max_color when t = 1,
     * due to floating-point arithmetic error. This form may be used when the
     * hardware has a native fused multiply-add instruction.
     */
    static rgb_color color_lerp( 
      rgb_color min_color, 
      rgb_color max_color, 
      double t);

    /* ----- CLAMP ----- 
     * taken from: https://en.cppreference.com/w/cpp/algorithm/clamp
     */
    template<class T>
    static constexpr const T& clamp( const T& v, const T& lo, const T& hi );

    /* ---- custom log scale ---- 
     * designed to make most apparent the difference between 0.01 and 0.2, to make
     * somewhat apparent the difference between 0.2 and 0.5, and to minimize
     * difference in values from 0.5 to 1.0
     * 
     * designed to be applied to saturation values before they are interpolated
     * with color_lerp
     *
     * expects 0.0 <= value <= 1.0
     */
    static double scale(double value);


    /* ======== Helper functions: cairo ======== 
     *
     * These are helper functions used by draw_diagram. They can be used
     * elsewhere but are not intended for use elsewhere, and thus their scopes
     * are fairly limited.
     *
     * each function begins with a call to cairo_save and ends with a call to
     * cairo_restore so that settings are preserved across calls
     */

    /* used by pango_cairo_draw_text */
    static void pango_cairo_make_text_layout(
      PangoLayout *layout,
      PangoFontDescription *font_desc,
      std::string text,
      int width,
      PangoAlignment alignment = PangoAlignment::PANGO_ALIGN_LEFT,
      int height = -1);

    /* used by pango_cairo_draw_text */
    static void pango_cairo_draw_layout(
      cairo_t * cr,
      double x,
      double y,
      PangoLayout *layout,
      bool vertical = false);
    
    /* ---- draw text ----
     *
     * Draws text at x, y. x and y should indicate the top-left corner of the
     * text box. Will automatically take as much vertical space as needed, but
     * will limit to the horizonatal space specified, adding new lines as
     * needed to maintain the specified text box width.
     *
     * this function returns the vertical distance needed to reach the
     * rectangle. For alignments LEFT and BOTTOM, this is the distance taken by
     * the text. For INSIDE, it is 0.
     *
     * if "vertical" is true, "text_box_width" will be applied in the vertical
     * cairo dimension. Therefore, vertical distance is fixed and horizontal
     * distance is not. As a result, this function will instead return the
     * horizontal distance taken by the text
     */
    static double pango_cairo_draw_text(
      cairo_t * cr,
      double x,
      double y,
      int text_box_width,
      std::string text,
      PangoFontDescription * font_desc,
      PangoAlignment alignment = PangoAlignment::PANGO_ALIGN_LEFT,
      bool vertical = false);

    /* ---- draw swatch ----
     * Used to create legend on saturation diagram. Also used to test gradients
     * that may be used to indicate saturation in diagrams 
     */
    static void cairo_draw_swatch(
      cairo_t *cr,
      rgb_color min_color, 
      rgb_color max_color,
      unsigned x,
      unsigned y,
      unsigned width,
      unsigned height,
      unsigned num_steps); 

    /* ---- draw component ----
     *
     * Font size will be adjusted to be approximately 1/3 the height of the
     * box. Text will be centered horizontally (and vertically in all positions
     * except BOTTOM)
     *
     * Returns the distance needed for the text. This distance is in the
     * vertical dimension for position BOTTOM and horizontal for LEFT. The
     * rectangle will take the rest of <width>
     *
     */
    static double cairo_draw_component(
      cairo_t *cr,
      double x,
      double y,
      double width,
      double height,
      rgb_color fill_color,
      std::string label,
      PangoFontDescription * font_desc,
      label_position position = label_position::INSIDE);

  private:
};