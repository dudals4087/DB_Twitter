<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"
         import="java.sql.*, java.util.UUID" %>
<%@ include file="dbconn.jsp" %>
<%
    request.setCharacterEncoding("UTF-8");

    String currentUser = (String) session.getAttribute("currentUser");
    // 로그인 체크
    if (currentUser == null || currentUser.trim().isEmpty()) {
        response.sendRedirect("login.jsp");
        return;
    }

    String reqId  = request.getParameter("req_id");
    String action = request.getParameter("action");
    if (reqId != null)  reqId  = reqId.trim();
    if (action != null) action = action.trim();

    String referer = request.getHeader("Referer");
    if (referer == null) referer = "profile.jsp";

    // 파라미터 없으면 복귀
    if (reqId == null || reqId.isEmpty() || action == null || action.isEmpty()) {
        response.sendRedirect(referer);
        return;
    }

    String requester = null;
    String target    = null;

    try {
        // 1. 요청 정보 조회 (누가 누구에게)
        String q = "SELECT requester_id, target_id FROM follow_requests WHERE req_id = ?";
        try (PreparedStatement ps = con.prepareStatement(q)) {
            ps.setString(1, reqId);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    requester = rs.getString("requester_id");
                    target    = rs.getString("target_id");
                }
            }
        }

        // 권한 체크: 내가 타겟(수락자)이어야 함
        if (requester == null || target == null || !currentUser.equals(target)) {
            response.sendRedirect(referer);
            return;
        }

        // 트랜잭션 시작
        boolean oldAuto = con.getAutoCommit();
        con.setAutoCommit(false);

        try {
            if ("approve".equalsIgnoreCase(action)) {
                // 2. 승인 로직
                
                // 중복 체크
                boolean already = false;
                String chk = "SELECT 1 FROM followings WHERE user_id = ? AND follower_id = ?";
                try (PreparedStatement ps = con.prepareStatement(chk)) {
                    ps.setString(1, target);    // 나 (팔로우 당할 사람)
                    ps.setString(2, requester); // 상대 (팔로우 할 사람)
                    try (ResultSet rs = ps.executeQuery()) {
                        if (rs.next()) already = true;
                    }
                }

                if (!already) {
                    // [핵심 수정] f_id 생성 및 포함 INSERT
                    String newFid = "fw" + UUID.randomUUID().toString().replace("-", "").substring(0, 10);
                    
                    // user_id = 나(Target), follower_id = 상대(Requester) -> 상대가 나를 팔로우함
                    String ins = "INSERT INTO followings (f_id, user_id, follower_id) VALUES (?, ?, ?)";
                    try (PreparedStatement ps = con.prepareStatement(ins)) {
                        ps.setString(1, newFid);    // f_id (필수!)
                        ps.setString(2, target);    // user_id (나)
                        ps.setString(3, requester); // follower_id (상대)
                        ps.executeUpdate();
                    }
                }

                // 3. 요청 삭제
                String del = "DELETE FROM follow_requests WHERE req_id = ?";
                try (PreparedStatement ps = con.prepareStatement(del)) {
                    ps.setString(1, reqId);
                    ps.executeUpdate();
                }

            } else if ("reject".equalsIgnoreCase(action)) {
                // 4. 거절 로직 (요청만 삭제)
                String del = "DELETE FROM follow_requests WHERE req_id = ?";
                try (PreparedStatement ps = con.prepareStatement(del)) {
                    ps.setString(1, reqId);
                    ps.executeUpdate();
                }
            }

            con.commit();
            con.setAutoCommit(oldAuto);

        } catch (Exception e) {
            con.rollback();
            con.setAutoCommit(true);
            throw e;
        }

    } catch (Exception e) {
        e.printStackTrace();
        // 에러 발생 시 팝업 띄우기 (또 다른 에러 방지용)
        String msg = e.getMessage().replace("'", "").replace("\n", " ");
%>
        <script>
            alert("처리 중 오류 발생: [ <%= msg %> ]");
            history.back();
        </script>
<%
        return;
    } finally {
        if (con != null) { try { con.close(); } catch (Exception ignore) {} }
    }

    // 성공 시 복귀
    response.sendRedirect(referer);
%>