<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"
         import="java.util.UUID, java.sql.*, java.net.URLEncoder" %>
<%@ include file="dbconn.jsp" %>
<%
    request.setCharacterEncoding("UTF-8");

    String currentUser = (String)session.getAttribute("currentUser");
    if (currentUser == null) {
        response.sendRedirect("login.jsp");
        return;
    }

    String postId   = request.getParameter("post_id");
    String content  = request.getParameter("content");
    // [수정됨] 대댓글을 달 부모 댓글의 ID를 받습니다. (comment_id로 명칭 통일)
    String parentCommentId = request.getParameter("parent_comment_id"); 
    
    // (기존의 parentId 변수와 헷갈리지 않게 변수명 변경)

    if (postId != null) postId = postId.trim();
    if (content != null) content = content.trim();
    if (parentCommentId != null) parentCommentId = parentCommentId.trim();

    if (postId == null || postId.isEmpty() || content == null || content.isEmpty()) {
        response.sendRedirect("postDetail.jsp?post_id=" + URLEncoder.encode(postId == null ? "" : postId, "UTF-8"));
        return;
    }

    PreparedStatement ps = null;
    try {
        if (parentCommentId != null && !parentCommentId.isEmpty()) {
            // [분기 1: 대댓글] replies 테이블에 저장
            String replyId = "r" + UUID.randomUUID().toString().replace("-", "").substring(0, 10);
            String sql =
                "INSERT INTO replies (reply_id, comment_id, writer_id, content, created_at) " +
                "VALUES (?, ?, ?, ?, NOW())";

            ps = con.prepareStatement(sql);
            ps.setString(1, replyId);
            ps.setString(2, parentCommentId); // 부모 댓글 ID
            ps.setString(3, currentUser);
            ps.setString(4, content);
            
        } else {
            // [분기 2: 일반 댓글] comments 테이블에 저장
            String commentId = "c" + UUID.randomUUID().toString().replace("-", "").substring(0, 10);
            String sql =
                "INSERT INTO comments (comment_id, content, writer_id, post_id, num_of_likes) " +
                "VALUES (?, ?, ?, ?, 0)";

            ps = con.prepareStatement(sql);
            ps.setString(1, commentId);
            ps.setString(2, content);
            ps.setString(3, currentUser);
            ps.setString(4, postId);
        }

        ps.executeUpdate();

    } catch (Exception e) {
        e.printStackTrace();
    } finally {
        if (ps != null) try { ps.close(); } catch (Exception ignore) {}
        if (con != null) try { con.close(); } catch (Exception ignore) {}
    }

    response.sendRedirect("postDetail.jsp?post_id=" + URLEncoder.encode(postId, "UTF-8"));
%>