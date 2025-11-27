<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"
         import="java.sql.*, java.util.*" %>
<%@ include file="dbconn.jsp" %>
<%
    request.setCharacterEncoding("UTF-8");

    String currentUser = (String)session.getAttribute("currentUser");
    if (currentUser == null) {
        response.sendRedirect("login.jsp");
        return;
    }

    String postId = request.getParameter("post_id");
    if (postId != null) postId = postId.trim();

    if (postId == null || postId.isEmpty()) {
        response.sendRedirect("main.jsp");
        return;
    }

    String writerId = null;
    try {
        // 작성자 확인
        String sql = "SELECT writer_id FROM posts WHERE post_id = ?";
        try (PreparedStatement ps = con.prepareStatement(sql)) {
            ps.setString(1, postId);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    writerId = rs.getString("writer_id");
                }
            }
        }

        if (writerId == null || !currentUser.equals(writerId)) {
            // 작성자가 아니면 그냥 되돌리기
            response.sendRedirect("postDetail.jsp?post_id=" + postId);
            return;
        }

        con.setAutoCommit(false);

        // 이 게시글의 모든 댓글 id 가져오기
        List<String> commentIds = new ArrayList<String>();
        try (PreparedStatement ps = con.prepareStatement(
                "SELECT comment_id FROM comments WHERE post_id = ?")) {
            ps.setString(1, postId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) commentIds.add(rs.getString(1));
            }
        }

        // 댓글 좋아요 삭제 + 댓글 삭제
        try (PreparedStatement delCL = con.prepareStatement(
                 "DELETE FROM comment_likes WHERE comment_id = ?");
             PreparedStatement delC = con.prepareStatement(
                 "DELETE FROM comments WHERE comment_id = ?")) {

            for (String cid : commentIds) {
                delCL.setString(1, cid);
                delCL.executeUpdate();

                delC.setString(1, cid);
                delC.executeUpdate();
            }
        }

        // 게시글 좋아요 삭제
        try (PreparedStatement ps = con.prepareStatement(
                "DELETE FROM post_likes WHERE post_id = ?")) {
            ps.setString(1, postId);
            ps.executeUpdate();
        }

        // 게시글 삭제
        try (PreparedStatement ps = con.prepareStatement(
                "DELETE FROM posts WHERE post_id = ?")) {
            ps.setString(1, postId);
            ps.executeUpdate();
        }

        con.commit();
    } catch (Exception e) {
        e.printStackTrace();
        try { con.rollback(); } catch (Exception ignore) {}
    } finally {
        try { con.setAutoCommit(true); } catch (Exception ignore) {}
        if (con != null) try { con.close(); } catch (Exception ignore) {}
    }

    response.sendRedirect("main.jsp");
%>
