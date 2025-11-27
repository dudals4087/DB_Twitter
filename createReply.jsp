<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"
         import="java.sql.*, java.util.UUID, java.net.URLEncoder" %>
<%@ include file="dbconn.jsp" %>
<%
    request.setCharacterEncoding("UTF-8");

    String currentUser = (String) session.getAttribute("currentUser");
    if (currentUser == null) {
        if (con != null) {
            try { con.close(); } catch (Exception ignore) {}
        }
        response.sendRedirect("login.jsp");
        return;
    }

    String commentId = request.getParameter("comment_id");
    String postId    = request.getParameter("post_id");
    String content   = request.getParameter("content");

    if (commentId != null) commentId = commentId.trim();
    if (postId    != null) postId    = postId.trim();
    if (content   != null) content   = content.trim();

    if (commentId == null || commentId.isEmpty() ||
        postId    == null || postId.isEmpty()) {
        if (con != null) {
            try { con.close(); } catch (Exception ignore) {}
        }
        response.sendRedirect("main.jsp");
        return;
    }

    if (content == null || content.isEmpty()) {
        if (con != null) {
            try { con.close(); } catch (Exception ignore) {}
        }
        response.sendRedirect("postDetail.jsp?post_id=" +
                URLEncoder.encode(postId, "UTF-8"));
        return;
    }

    try {
        String rid = "r" + UUID.randomUUID().toString().replace("-", "").substring(0, 10);

        String sql =
            "INSERT INTO replies (reply_id, comment_id, writer_id, content) " +
            "VALUES (?, ?, ?, ?)";
        try (PreparedStatement ps = con.prepareStatement(sql)) {
            ps.setString(1, rid);
            ps.setString(2, commentId);
            ps.setString(3, currentUser);
            ps.setString(4, content);
            ps.executeUpdate();
        }
    } catch (Exception e) {
        e.printStackTrace();
    } finally {
        if (con != null) {
            try { con.close(); } catch (Exception ignore) {}
        }
    }

    response.sendRedirect("postDetail.jsp?post_id=" +
            URLEncoder.encode(postId, "UTF-8"));
%>
